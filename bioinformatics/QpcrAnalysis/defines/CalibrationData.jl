#===============================================================================

    CalibrationData.jl

    container for calibration data

    data has 3 dimensions:
    1. Well     :0 - :15
    2. Channel  1, 2
    3. Dye      water, dye1, dye2

    Author: Tom Price
    Date:   June 2019

===============================================================================#

import DataStructures.OrderedDict
import StaticArrays: SArray


struct CalibrationData{N <: NumberOfChannels, R <: Union{Int_T,Float_T}}
    array       ::SArray{S,R,3} where {S <: Tuple}
    ## inner constructors supply type parameters
    ## and enforce constraints on size of data array
    CalibrationData(
        ::Type{SingleChannel},
        data ::AbstractArray{R}) where{R <: Union{Int_T,Float_T}} =
            new{SingleChannel,R}(SArray{Tuple{size(data,1),1,2},R}(data))
    CalibrationData(
        ::Type{DualChannel},
        data ::AbstractArray{R}) where{R <: Union{Int_T,Float_T}} =
            new{DualChannel,R}(SArray{Tuple{size(data,1),2,3},R}(data))
end

## parser / outer constructor
function CalibrationData(calib ::Associative)
    local water, dye1, dye2 ## not enum
    num_wells = count_wells(calib)
    water     = calib[WATER_KEY][FLUORESCENCE_VALUE_KEY]
    R         = water |> first |> first |> typeof
	if (R == Int64 && Int_T != Int64)
		R = Int_T
	end
	
    dye1      = calib[CHANNEL_KEY * "_1"][FLUORESCENCE_VALUE_KEY]
    if length(dye1) > 1 && thing(dye1[2]) && haskey(calib, CHANNEL_KEY * "_2")
        dye2  = calib[CHANNEL_KEY * "_2"][FLUORESCENCE_VALUE_KEY]
        data  = try
            [water, dye1, dye2] |> gather(vcat) |> gather(hcat) |>
                morph(num_wells,2,3) |> mold(bless(R))
        catch
            warn(logger, "dual channel calibration data are in the wrong format")
            rethrow()
        end ## try
        return CalibrationData(DualChannel, data)
    end ## if
    ## else single channel
    data  = try
        [water, dye1] |> moose(first, hcat) |> morph(num_wells,1,2) |> mold(bless(R))
    catch
        warn(logger, "single channel calibration data are in the wrong format")
        rethrow()
    end ## try
    return CalibrationData(SingleChannel, data)
end ## CalibrationData()
