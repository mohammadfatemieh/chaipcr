#
# Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
# For more information visit http://www.chaibio.com
#
# Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class MeltCurveDatum < ActiveRecord::Base
  include TargetsHelper
	include Swagger::Blocks

  belongs_to :experiment

	swagger_schema :MeltCurveData do
		property :partial do
			key :type, :boolean
			key :description, 'Keep polling the data until partial is false'
		end
		property :ramps do
			key :description, 'Contains temperature, normalized_data, derivative_data, tm and area arrays'
			key :type, :array
			items do
				property :ramp_id do
					key :type, :integer
				end
				property :melt_curve_data do
					key :type, :array
          key :description, "[{'well_num':1, 'target_id':1, 'temperature':[0,1,2,3,4,5], 'normalized_data':[0,1,2,3,4,5], 'derivative_data':[0,1,2,3,4,5], 'tm':[1,2,3], 'area':[2,4,5]},
                              {'well_num':2, 'target_id':1, 'temperature':[0,1,2,3,4,5], 'normalized_data':[0,1,2,3,4,5], 'derivative_data':[0,1,2,3,4,5], 'tm':[1,2,3], 'area':[2,4,5]}]"
					items do
            extend SwaggerHelper::PropertyWellnum

						property :target_id do
							key :type, :integer
							key :description, 'Target ID'
						end
						property :temperature do
							key :type, :array
							key :description, 'Temperature, in degree C'
						end
						property :normalized_data do
							key :type, :array
							key :description, '?'
						end
						property :derivative_data do
							key :type, :array
							key :description, '?'
						end
						property :tm do
							key :type, :array
							key :description, '?'
						end
						property :area do
							key :type, :array
							key :description, '?'
						end
					end
				end
				property :targets do
					key :type, :array
          key :description, "[{'target_id':1,'target_name':'Ch 1','channel':1},{'target_id':2,'target_name':'Ch 2','channel':2}]"
					items do
						property :target_id do
							key :type, :integer
							key :description, 'Target ID'
            end
						property :target_name do
							key :type, :string
							key :description, 'Target name'
              key :default, "Ch 1 or Ch 2"
            end
						property :channel do
							key :type, :integer
							key :description, 'Channel'
            end
          end
        end
			end
		end
	end

  scope :for_experiment, lambda {|experiment_id| where(["#{table_name}.experiment_id=?", experiment_id])}
  scope :for_stage, lambda {|stage_id| where(["#{table_name}.stage_id=?", stage_id])}
  scope :group_by_well, -> { select("#{table_name}.experiment_id,#{table_name}.ramp_id,#{table_name}.channel,#{table_name}.well_num,MAX(#{table_name}.id) AS id,GROUP_CONCAT(temperature SEPARATOR ',') AS temperature,GROUP_CONCAT(fluorescence_value SEPARATOR ',') AS fluorescence_data").group("well_num") }

  def self.new_data_generated?(experiment, stage_id)
    lastrow = self.for_experiment(experiment.id).for_stage(stage_id).order("id DESC").select("temperature").first
    if lastrow
      if experiment.cached_temperature == nil
        return lastrow
      else
        if experiment.running?
          return ((lastrow.temperature - experiment.cached_temperature).abs >= 1)? lastrow : nil
        else #experiment completed
          return (lastrow.temperature != experiment.cached_temperature)? lastrow : nil
        end
      end
    else
      return nil
    end
  end

  def self.maxid(experiment_id, stage_id)
    self.for_experiment(experiment_id).for_stage(stage_id).maximum(:id)
  end
  
  def self.julia_hash(experiment_id, stage_id)
    results = {}
    MeltCurveDatum.for_experiment(experiment_id).for_stage(stage_id).order(:channel, :well_num, :id).each do |data|
      results[:fluorescence_value] ||= Array.new
      results[:temperature] ||= Array.new
      results[:well_num] ||= Array.new
      results[:channel] ||= Array.new
      results[:fluorescence_value] << data.fluorescence_value
      results[:temperature] << Float(data.temperature)
      results[:well_num] << data.well_num
      results[:channel] << data.channel
    end
    results
  end
  
  def well_num
    read_attribute(:well_num)+1
  end
end
