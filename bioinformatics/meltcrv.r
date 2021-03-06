# meltcrv


# function: get melting curve data and output it for plotting as well as Tm
process_mc <- function(
    db_usr, db_pwd, db_host, db_port, db_name, # for connecting to MySQL database
    exp_id, stage_id, calib_info, # for selecting data to analyze
    dye_in='FAM', dyes_2bfild=NULL, 
    dcv=TRUE, # logical, whether to perform multi-channel deconvolution
    auto_span_smooth=FALSE, 
    span_smooth_default=0.015, # qpcR default 0.05. used: 0.005, 0.01, 0.015, 0.02, 0.05, 0.1, 0.15, 0.2
    span_smooth_factor=7.2, 
    max_temp=1000, # analyze only the data with temperature lower than this
    mc_plot=FALSE, # whether to plot melting curve data
    extra_output=FALSE, 
    show_running_time=FALSE, # option to show time cost to run this function
    ... # arguments passed onto `mc_tm_pw`
    ) {
    
    # start counting for running time
    func_name <- 'process_mc'
    start_time <- proc.time()[['elapsed']]
    
    db_etc_out <- db_etc(
        db_usr, db_pwd, db_host, db_port, db_name, 
        exp_id, stage_id, calib_info)
    db_conn <- db_etc_out[['db_conn']]
    calib_info <- db_etc_out[['calib_info']]
    
    message('max_temp: ', max_temp)
    
    mcd_qry <- sprintf('SELECT channel
                           FROM melt_curve_data 
                           WHERE experiment_id=%d AND stage_id=%d',
                           exp_id, stage_id)
    mcd_channel <- dbGetQuery(db_conn, mcd_qry)
    channels <- unique(mcd_channel[,'channel'])
    num_channels <- length(channels)
    
    # { # pre-deconvolution, process all available channels
    # names(channels) <- channels
    # if (length(channels) == 1) dcv <- FALSE
    # }
    
    # pre-deconvolution, process only channel 1
    channels <- c('1'='1')
    dcv <- FALSE
    
    oc_data <- prep_optic_calib(db_conn, calib_info, dye_in, dyes_2bfild)
    
    mc_calib_mtch <- process_mtch(
        channels, 
        matrix2array=TRUE, 
        func=get_mc_calib, 
        db_conn, 
        exp_id, stage_id, 
        oc_data, 
        max_temp, 
        show_running_time)
    dbDisconnect(db_conn)
    
    mc_calib_mtch_bych <- mc_calib_mtch[['pre_consoli']]
    pre_dcv_fc_wT_bych <- lapply(channels, function(channel) mc_calib_mtch_bych[[as.character(channel)]][['fc_wT']]) # `pre_dcv_fc_wT_bych` inherit channels as names from `channels`
    fc_wT_bych <- pre_dcv_fc_wT_bych
    
    mc_calib_array <- mc_calib_mtch[['post_consoli']][['fluo_calib']]
    
    if (dcv) {
        k_inv_array <- k_list[['k_inv_array']]
        # k_inv_array[,,] <- rep(c(1, 0, 1, 0), times=16) # addition with flexible ratio instead of deconvolution
        dcvd_array <- deconv(mc_calib_array, k_inv_array)
        fc_wT_colnames <- colnames(fc_wT_bych[[1]])
        fluo_colnames <- fc_wT_colnames[grepl('fluo_', fc_wT_colnames)]
        for (channel in channels) {
            dcvd_mtx_per_channel <- dcvd_array[as.character(channel),,]
            fc_wT_bych[[as.character(channel)]][,fluo_colnames] <- dcvd_mtx_per_channel }}
    
    # post-deconvolution, process for only 1 channel
    # fc_wT_bych <- fc_wT_bych[1] # channel 1
    # fc_wT_bych <- fc_wT_bych[2] # channel 2
    
    
    mc_out_pc <- process_mtch(
        fc_wT_bych, 
        matrix2array=FALSE, # doesn't matter because no original output was matrix
        func=mc_tm_all, 
        auto_span_smooth, 
        span_smooth_default, 
        span_smooth_factor, 
        mc_plot, 
        show_running_time,
        ... # arguments passed onto `mc_tm_pw`
        )[['pre_consoli']]
    
    if (extra_output) {
        mc_out <- list( # each element is a list whose each element represents a channel
            'mc_bywell'=mc_out_pc, # each channel element is a list whose each element is a well
            'num_channels'=num_channels, 
            'fc_wT'=fc_wT_bych, 'pre_dcv_fc_wT'=pre_dcv_fc_wT_bych # each channel element of fc_wT or pre_dcv_fc_wT_bych is a matrix formatted as input for `meltcurve` by qpcR, where columns are alternating 'temp' and 'fluo'.
            )
    } else mc_out <- mc_out_pc
    
    # report time cost for this function
    end_time <- proc.time()[['elapsed']]
    if (show_running_time) message('`', func_name, '` took ', round(end_time - start_time, 2), ' seconds.')
    
    check_obj2br(mc_out)
    
    return(mc_out)
}


# function: get melting curve data from MySQL database and perform water calibration
get_mc_calib <- function(
    channel, 
    db_conn, 
    exp_id, stage_id,
    oc_data, 
    max_temp, 
    show_running_time
    ) {
    
    # start counting for running time
    func_name <- 'get_mc_calib'
    start_time <- proc.time()[['elapsed']]
    
    message('get_mc_calib')
    
    # get fluorescence data for melting curve
    fluo_qry <- sprintf(
        'SELECT id, stage_id, well_num, temperature, fluorescence_value, experiment_id 
            FROM melt_curve_data 
            WHERE experiment_id=%d AND stage_id=%d AND channel=%d AND temperature <= %f
            ORDER BY well_num, temperature',
        exp_id, stage_id, as.numeric(channel), max_temp)
    fluo_sel <- dbGetQuery(db_conn, fluo_qry)
    
    num_wells <- length(unique(fluo_sel[,'well_num']))
    
    # split temperature and fluo data by well_num
    tf_list <- split(fluo_sel[, c('temperature', 'fluorescence_value')], fluo_sel$well_num)
    
    # add NA to the end if not enough data
    max_len <- max(sapply(tf_list, function(tf) dim(tf)[1]))
    tf_ladj <- lapply(tf_list, function(tf) rbind(as.matrix(tf), matrix(NA, nrow=(max_len-dim(tf)[1]), ncol=2)))
    
    # water calibration
    fluo_mtx <- do.call(cbind, lapply(tf_ladj, function(tf) tf[, 'fluorescence_value']))
    fluo_calib <- optic_calib(fluo_mtx, oc_data, channel, minus_water=TRUE, show_running_time)$fluo_calib[,2:(num_wells+1)] # indice 2:(num_wells+1) were added 1, due to adply in optic_calib, which automatically add a column at index 1 of output from rownames of input array (1st argument)
    
    # combine temperature and fluo data
    fluo_calib_list <- alply(fluo_calib, .margins=2, .fun=function(col1) col1)
    fc_wT <- do.call(
        cbind, 
        lapply(1:num_wells, function(well_num) cbind(
            tf_ladj[[well_num]][, 'temperature'], 
            fluo_calib_list[[well_num]])))
    colnames(fc_wT) <- paste(rep(c('temp', 'fluo'), times=num_wells), rep(unique(fluo_sel$well_num), each=2), sep='_')
    
    mc_calib <- list('fluo_calib'=as.matrix(fluo_calib),  # change data frame to matrix for ease of constructing array
                     'fc_wT'=fc_wT)
    
    # report time cost for this function
    end_time <- proc.time()[['elapsed']]
    if (show_running_time) message('`', func_name, '` took ', round(end_time - start_time, 2), ' seconds.')
    
    return(mc_calib)
}


# function: extract melting curve data and Tm for each well
mc_tm_pw <- function(
    mt_pw, 
    qt_prob=0.64, # quantile probability point for normalized -df/dT (range 0-1)
    max_normd_qtv=0.601, # maximum normalized -df/dT values (range 0-1) at the quantile probablity point
    top_N=4, # top number of Tm peaks to report
    min_frac_report=0.1 # minimum area fraction of the Tm peak to be reported in regards to the largest real Tm peak
    ) { # per well
    
    # to test
    #message('qt_prob: ', qt_prob)
    #message('max_normd_qtv: ', max_normd_qtv)
    
    Fluo_ori <- mt_pw[,'Fluo']
    Fluo_normd <- Fluo_ori - min(Fluo_ori)
    mc <- cbind(mt_pw[,'Temp'], Fluo_normd, mt_pw[,'df.dT'])
    colnames(mc) <- c('Temp', 'Fluo', '-df/dT')
    mc <- as.data.frame(mc[c(seq(1, dim(mc)[1], 10), dim(mc)[1]),]) # select 1/10 sparse data points. also include `dim(mc)[1]` to have at least 2 rows to maintain data frame format. `as.data.frame` to ensure proper plotting.
    
    raw_tm <- na.omit(mt_pw[, c('Tm', 'Area')])
    
    range_dfdT <- range(mc[,'-df/dT'])
    #summit_pos <- which.max(mc[,'-df/dT']) # original: invalid when -df/dT very high at the beginning of melt curve
    summit_pos <- which.min(sapply(mc[,'Temp'], function(temp) abs(temp - raw_tm[which.max(raw_tm$Area), 'Tm']))) # which(mc[,'Temp'] == raw_tm[which.max(raw_tm$Area), 'Tm']) # exact equality doesn't work on beaglebone possibly due to rounding issues. # postion in -df/dT curve corresponding to Tm peak of largest area.
    dfdT_normd <- (mc[,'-df/dT'] - range_dfdT[1]) / (range_dfdT[2] - range_dfdT[1])
    # range_dfdT[1] == min(mc[,'-df/dT']). range_dfdT[2] == max(mc[,'-df/dT']).
    
    if (dim(raw_tm)[1] == 0) {
        larger_normd_qtv_of_two_sides <- max_normd_qtv + 1 # dummy value simply to make TRUE `larger_normd_qtv_of_two_sides > max_normd_qtv`
    } else {
        larger_normd_qtv_of_two_sides <- max(sapply(
            list(1:summit_pos, summit_pos:length(dfdT_normd)),
            function(idc) quantile(dfdT_normd[idc], qt_prob)
        ))
    }
    
    if (larger_normd_qtv_of_two_sides > max_normd_qtv) {
        tm <- raw_tm[FALSE,]
        tm_reported_keywords <- c('No', '>')
    } else {
        tm_sorted <- raw_tm[order(-raw_tm$Area),]
        tm_topN <- na.omit(tm_sorted[1:top_N,])
        tm <- tm_topN[tm_topN$Area >= tm_topN[1, 'Area'] * min_frac_report,]
        tm_reported_keywords <- c('Yes', '<=')
    }
    
    return(list(
        'mc'=mc, 'tm'=tm, 'raw_tm'=raw_tm,
        'tm_reported'=sprintf('%s. The larger normalized quantile value of the left and right sides of the summit on the negative derivative curve %f %s `max_normd_qtv` %f.', tm_reported_keywords[1], larger_normd_qtv_of_two_sides, tm_reported_keywords[2], max_normd_qtv)
    ))
}


# function: output melting curve data and Tm for all the wells
mc_tm_all <- function(
    fc_wT, 
    auto_span_smooth, 
    span_smooth_default, 
    span_smooth_factor, 
    mc_plot, 
    show_running_time, 
    ...) { # options to pass onto `mc_tm_pw`
    
    # start counting for running time
    func_name <- 'mc_tm_all'
    start_time <- proc.time()[['elapsed']]
    
    mt_ori <- meltcurve(
        fc_wT, 
        temp_1side=2, # xqrm
        auto_span_smooth=auto_span_smooth, # xqrm
        span_smooth_default=span_smooth_default, # xqrm. 
        span_smooth_factor=span_smooth_factor, # xqrm
        span.peaks=51, # default 51.
        plot=mc_plot) # using qpcR function `meltcurve`
    mt_out <- lapply(mt_ori, FUN=mc_tm_pw, ...)
    names(mt_out) <- colnames(fc_wT)[seq(2, dim(fc_wT)[2], by=2)]
    
    # report time cost for this function
    end_time <- proc.time()[['elapsed']]
    if (show_running_time) message('`', func_name, '` took ', round(end_time - start_time, 2), ' seconds.')
    
    # Return a named list whose length is number of wells. 
    # The name of each element is in the format of `paste('fluo', well_name, sep='_')`
    return(mt_out)
}








