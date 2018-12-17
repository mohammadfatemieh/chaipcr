# Notes

# The following are not implemented yet:
# ensure_ci in shared.jl
# get_mysql_data_well in shared.jl
# get_k in deconv.jl <- deconV in deconv.jl <- dcv_aw in calib.jl
#                    <- analyze_customized/optical_cal.jl

function startup()
    #
    # ;cd ~/chaipcr/bioinformatics/QpcrAnalysis
    # ;sudo mount -t vboxsf shared /mnt/share
    #
    push!(LOAD_PATH,pwd())
    LOAD_FROM_DIR=pwd()
end


function load_dependencies()

    using QpcrAnalysis

    import DataStructures.OrderedDict
    import JuMP: @variable, @objective, @NLobjective, @constraint,
        Model, solve, getvalue, getobjectivevalue
    import Ipopt.IpoptSolver
    import DataArrays.DataArray
    import Clustering: ClusteringResult, kmeans!, kmedoids!, silhouettes
    import Combinatorics.combinations
    import JLD.load
    import JSON
    import Dierckx: Spline1D, derivative
    import DataFrames: DataFrame, by
    import FactCheck: @fact, facts, convert, clear_results, getindex

    # development & testing
    import Base.Test
    immport FactCheck: facts, context, @fact, clear_results, exitstatus, less_than_or_equal
    FactCheck.clear_results()

    include("shared.jl")

    # dispatch
    include("action_types.jl")
    include("dispatch.jl")

    # data format verification
    include("verify_request.jl")
    include("verify_response.jl")

    # calibration
    include("deconv.jl")
    include("adj_w2wvaf.jl")
    include("calib.jl")

    # amplification
    include("amp_models/types_for_amp_models.jl")
    include("amp_models/sfc_models.jl")
    include("amp_models/MAKx.jl")
    include("amp_models/MAKERGAUL.jl")
    include("types_for_allelic_discrimination.jl")
    include("amp.jl")
    include("allelic_discrimination.jl")

    include("standard_curve.jl")

    # melt curve
    include("multi_channel.jl")
    include("supsmu.jl")
    include("meltcrv.jl")

    # analyze_customized
    include("analyze_customized/thermal_performance_diagnostic.jl")
    include("analyze_customized/optical_test_single_channel.jl")
    include("analyze_customized/optical_test_dual_channel.jl")
    include("analyze_customized/optical_cal.jl")
    include("analyze_customized/thermal_consistency.jl")

end # load_dependencies


function old()

    # amplification tests
    include("action_types.jl")
    include("verify_request.jl")
    include("verify_response.jl")
    include("dispatch.jl")
    include("amp.jl")
    include("calib.jl")
    include("adj_w2wvaf.jl")
    include("deconv.jl")

    # meltcurve tests
    include("action_types.jl")
    include("verify_request.jl")
    include("verify_response.jl")
    include("dispatch.jl")
    include("calib.jl")
    include("adj_w2wvaf.jl")
    include("deconv.jl")
    include("meltcrv.jl")
    include("supsmu.jl")

    # thermal consistency
    include("action_types.jl")
    include("verify_request.jl")
    include("verify_response.jl")
    include("dispatch.jl")
    include("calib.jl")
    include("adj_w2wvaf.jl")
    include("deconv.jl")
    include("meltcrv.jl")
    include("supsmu.jl")
    include("thermal_consistency.jl")

    # thermal performance diagnostic
    include("action_types.jl")
    include("verify_request.jl")
    include("verify_response.jl")
    include("dispatch.jl")
    include("calib.jl")
    include("adj_w2wvaf.jl")
    include("deconv.jl")
    include("meltcrv.jl")
    include("supsmu.jl")
    include("thermal_performance_diagnostic")

    # optical tests
    include("action_types.jl")
    include("verify_request.jl")
    include("verify_response.jl")
    include("dispatch.jl")
    include("analyze_customized/optical_test_single_channel.jl")
    include("analyze_customized/optical_test_dual_channel.jl")

end


function test(
    debug ::Bool =true,
    verbose ::Bool =true
)
    load_dependencies()
    include("/mnt/share/verify_request.jl")
    test_results = OrderedDict()
    strip = [" single"," dual"," channel"]
    for action in keys(Action_DICT)
        for dataset in [:single_channel,:dual_channel]
            datafile = getfield(Action_DICT[action],dataset)
            if datafile != ""
                request = JSON.parsefile("../test/data/$datafile.json",dicttype=OrderedDict)
                body = String(JSON.json(request))
                FactCheck.clear_results()
                (ok, response_body) = dispatch(action,body,verbose=true,verify=true)
                test = replace(action,r"_"=>" ")
                for str in strip
                    test = replace(test,str=>"")
                end
                test = "$test " * replace(string(dataset),r"_"=>" ")
                println(test)
                test_results[test] = ok
            end # if dataset
        end # single/dual channel
    end # next action

    for test in keys(test_results)
        @printf("%s => %s\n",test,test_results[test])
    end

end


function old2()

    # single channel amplification test
    request = JSON.parsefile("../test/data/test_1ch_amp_169.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("amplification",String(JSON.json(request)),verify=true)
    ok

    # dual channel amplification tests
    request = JSON.parsefile("../test/data/xh-amp1.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("amplification",String(JSON.json(request)),verify=true)
    ok
    request = JSON.parsefile("../test/data/xh-amp2.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("amplification",String(JSON.json(request)),verify=true)
    ok

    ## debug version
    # request = JSON.parsefile("../test/data/xh-amp2.json"; dicttype=OrderedDict)
    # action_t=ActionType_DICT["amplification"]()
    # verify_request(action_t,request)
    # response = act(action_t,request)
    # verify_response(action_t,JSON.parse(JSON.json(response),dicttype=OrderedDict))

    k = JLD.load("$LOAD_FROM_DIR/k4dcv_ip84_calib79n80n81_vec.jld")["k4dcv"]
    kk = K4Deconv(k.k_s,k.k_inv_vec,k.inv_note)
    const K4DCV = kk

    # single channel melting curve test
    request = JSON.parsefile("../test/data/test_1ch_mc_170.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("meltcurve",String(JSON.json(request)),verify=true)
    ok

    # dual channel melting curve test
    request = JSON.parsefile("../test/data/test_2ch_mc_223.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("meltcurve",String(JSON.json(request)),verify=true)
    ok

    ## debug version
    # request = JSON.parsefile("../test/data/test_2ch_mc_223.json"; dicttype=OrderedDict)
    # action_t=ActionType_DICT["meltcurve"]()
    # verify_request(action_t,request)
    # response = act(action_t,request)
    # verify_response(action_t,JSON.parse(JSON.json(response),dicttype=OrderedDict))


    # single channel thermal consistency analysis
    request = JSON.parsefile("../test/data/test_1ch_tc_146.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("thermal_consistency",String(JSON.json(request)),verify=true)
    ok

    # dual channel thermal consistency analysis
    request = JSON.parsefile("../test/data/test_2ch_tc_145.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("thermal_consistency",String(JSON.json(request)),verify=true)
    ok

    ## debug version
    # request = JSON.parsefile("../test/data/test_2ch_tc_145.json"; dicttype=OrderedDict)
    # action_t=ActionType_DICT["thermal_consistency"]()
    # verify_request(action_t,request)
    # response = act(action_t,request)
    # verify_response(action_t,JSON.parse(JSON.json(response),dicttype=OrderedDict))


    # single channel thermal performance diagnostic
    request = JSON.parsefile("../test/data/test_1ch_tpd_126.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("thermal_performance_diagnostic",String(JSON.json(request)),verify=true)
    ok

    # dual channel thermal performance diagnostic
    request = JSON.parsefile("../test/data/test_2ch_tpd_131.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("thermal_performance_diagnostic",String(JSON.json(request)),verify=true)
    ok

    ## debug version
    # request = JSON.parsefile("../test/data/test_2ch_tpd_131.json"; dicttype=OrderedDict)
    # action_t=ActionType_DICT["thermal_performance_diagnostic"]()
    # verify_request(action_t,request)
    # response = act(action_t,request)
    # verify_response(action_t,JSON.parse(JSON.json(response),dicttype=OrderedDict))


    # single channel optical test
    request = JSON.parsefile("/mnt/share/test_1ch_ot_161.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("optical_test_single_channel",String(JSON.json(request)),verify=true)
    ok

    # dual channel optical test
    request = JSON.parsefile("/mnt/share/test_2ch_ot_190.json"; dicttype=OrderedDict)
    (ok, response_body) = dispatch("optical_test_dual_channel",String(JSON.json(request)),verify=true)
    ok

    ## debug version
    # request = JSON.parsefile("/mnt/share/test_2ch_ot_190.json"; dicttype=OrderedDict)
    # action_t=ActionType_DICT["optical_test_dual_channel"]()
    # verify_request(action_t,request)  
    # response = act(action_t,request)
    # verify_response(action_t,JSON.parse(JSON.json(response),dicttype=OrderedDict))


    # standard curve
        
    # test using fake data for now
    request=JSON.parse("""[
        {"well": [
            {"target": 1, "cq": 17.9, "quantity": {"m": 31.2, "b": -3.52}},
            {"target": 2, "cq": 18.1, "quantity": {"m": 27.8, "b": -3.61}}
        ]},
        {"well": [
            {"target": 1, "cq": 17.0, "quantity": {"m": 30.1, "b": -3.47}},
            {"target": 2, "cq": 17.8, "quantity": {"m": 27.5, "b": -3.58}}
        ]},
        {"well": [
            {"target": 1, "cq": 16.2, "quantity": {"m": 29.4, "b": -3.51}},
            {"target": 2, "cq": 17.9, "quantity": {"m": 28.2, "b": -3.55}}
        ]}
    ]"""; dicttype=OrderedDict)

    (ok, response_body) = dispatch("standard_curve",String(JSON.json(request)),verify=true)
    ok


    # optical calibration


    # test Julia server

    # shell script to start julia server
    # julia -e 'push!(LOAD_PATH,"/home/vagrant/chaipcr/bioinformatics/QpcrAnalysis/");include("/home/vagrant/chaipcr/bioinformatics/QpcrAnalysis/QpcrAnalysis.jl");include("/home/vagrant/chaipcr/bioinformatics/juliaserver.jl")' &

    include("../juliaserver.jl")

    # call using Julia object
    # run(`curl \
    #     --header "Content-Type: application/json" \
    #     --request "GET" \
    #     --data $(JSON.json(request)) \
    #     http://localhost:8081/experiments/250/amplification`)

    # system call\
    # cd bioinformatics/QpcrAnalysis
    # curl \
    #     --header "Content-Type: application/json" \
    #     --data @../test/test_1ch_amp.json \
    #     http://localhost:8081/experiments/250/amplification

    # system call\
    # cd bioinformatics/QpcrAnalysis
    # curl \
    #     --header "Content-Type: application/json" \
    #     --data @../test/test_1ch_meltcurve.json \
    #     http://localhost:8081/experiments/170/meltcurve

end




#