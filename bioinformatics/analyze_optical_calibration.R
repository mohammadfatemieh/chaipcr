# chaipcr/web/public/dynexp/optical_calibration/analyze.R
# use `prep_calib` to check validity of water calibration data

library(jsonlite)

analyze_optical_calibration <- function(
    db_usr, db_pwd, db_host, db_port, db_name, 
    exp_id, 
    calib_id=NULL, # not used
    verbose=FALSE, 
    out_json=TRUE) 
{
    message('db: ', db_name)
    db_conn <- dbConnect(RMySQL::MySQL(), 
                         user=db_usr, 
                         password=db_pwd, 
                         host=db_host, 
                         port=db_port, 
                         dbname=db_name)
    
    result1 <- try(prep_calib(db_conn, exp_id, verbose))
    
    if (class(result1) == 'try-error') {
        valid <- FALSE
        err <- 'Fluorescein calibrator was less fluorescent than water in some wells. Please retry with new fluorescein calibrator.'
    } else {
        valid <- TRUE
        err <- NULL }
    
    result2 <- list('valid'=unbox(valid), 'error_message'=unbox(err))
    
    if (out_json) result2 <- toJSON(result2)
    
    return(result2)
    #return(toJSON(result2))
}
