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
class Experiment < ActiveRecord::Base
  include Swagger::Blocks

	swagger_schema :Experiment do
		property :id do
      key :type, :integer
      key :format, :int64
      key :readOnly, true
    end
    property :guid do
			key :description, 'GUID of the experiment'
      key :type, :string
      key :readOnly, true
    end
    property :name do
			key :description, 'Name of the experiment'
      key :type, :string
    end
    property :notes do
			key :description, 'Notes of the experiment'
      key :type, :string
    end
    property :standard_experiment_id do
			key :description, 'imported standard experiment id'
      key :type, :integer
      key :format, :int64
    end
    property :type do
			key :description, 'experiment type'
      key :type, :string
			key :enum, ['user', 'diagnostic', 'calibration', 'test_kit']
      key :readOnly, true
    end
    property :time_valid do
      key :type, :boolean
      key :readOnly, true
    end
    property :created_at do
			key :description, 'Date at which the experiment was created'
      key :type, :string
      key :format, :date
      key :readOnly, true
    end
    property :started_at do
			key :description, 'Date at which the experiment was started'
      key :type, :string
      key :format, :date
      key :readOnly, true
    end
    property :completed_at do
			key :description, 'Date at which the experiment was completed'
      key :type, :string
      key :format, :date
      key :readOnly, true
    end
    property :completion_status do
			key :description, 'If the experiment was completed successfully or aborted'
      key :type, :string
      key :readOnly, true
    end
    property :completion_message do
			key :description, '?'
      key :type, :string
      key :readOnly, true
    end
	end

  swagger_schema :FullExperiment do
    allOf do
      schema do
        key :'$ref', :ErrorModel
      end
      schema do
        property :guid do
    			key :description, 'GUID of the experiment'
          key :type, :string
        end
        property :protocol do
          key :type, :object
          key :'$ref', :FullProtocol
        end
      end
      schema do
        key :'$ref', :Experiment
      end
    end
  end

  scope :for_well_layout, lambda {|well_layout_id| joins("well_layouts on well_layouts.experiment_id = experiments.id and well_layouts.parent_type = '#{Experiment.name}'").where(["well_layouts.id=?", well_layout_id])}

  validates :name, presence: true
  validate :validate

  belongs_to :experiment_definition
  
  has_one  :well_layout, ->{ where(:parent_type => Experiment.name) }
  has_many :fluorescence_data
  has_many :temperature_logs, -> {order("elapsed_time")} do
    def with_range(starttime, endtime, resolution)
      results = where("elapsed_time >= ?", starttime)
      if !endtime.blank?
        results = results.where("elapsed_time <= ?", endtime)
      end
      outputs = []
      counter = 0
      gap = (resolution.blank?)? 1 : resolution.to_i/1000
      results.each do |row|
        if counter == 0
          outputs << row
        end
        counter += 1
        if counter == gap
          counter = 0
        end
      end
      outputs
    end
  end

#  validates :time_valid, inclusion: {in: [true, false]}

  before_create do |experiment|
    experiment.time_valid = (Setting.time_valid)? 1 : 0
    experiment.create_well_layout!
  end

  before_destroy do |experiment|
    if experiment.running?
      errors.add(:base, "cannot delete experiment in the middle of running")
      throw :abort
    end
    if experiment.well_layout
      begin
        experiment.well_layout.destroy
      rescue  => e
        errors.add(:base, *experiment.well_layout.errors.full_messages)
        throw :abort
      end
    end
  end

  after_destroy do |experiment|
    if experiment_definition.experiment_type ==  ExperimentDefinition::TYPE_USER_DEFINED
      experiment_definition.destroy
    end

    TemperatureLog.delete_all(:experiment_id => experiment.id)
    TemperatureDebugLog.delete_all(:experiment_id => experiment.id)
    FluorescenceDatum.delete_all(:experiment_id => experiment.id)
    FluorescenceDebugDatum.delete_all(:experiment_id => experiment.id)
    MeltCurveDatum.delete_all(:experiment_id => experiment.id)
    AmplificationCurve.delete_all(:experiment_id => experiment.id)
    AmplificationDatum.delete_all(:experiment_id => experiment.id)
    CachedMeltCurveDatum.delete_all(:experiment_id => experiment.id)
  end

  def create_well_layout!
    if self.well_layout == nil
      if experiment_definition.well_layout != nil
        self.well_layout = experiment_definition.well_layout.copy
      else
        self.well_layout = WellLayout.new(:experiment_id=>id, :parent_type=>Experiment.name)
      end
      if !self.new_record?
        self.well_layout.save
      end
    end
  end
  
  def protocol
    experiment_definition.protocol
  end

  def editable?
    return started_at.nil? && experiment_definition.editable?
  end

  def ran?
    return !started_at.nil?
  end

  def running?
    return !started_at.nil? && completed_at.nil?
  end

  def diagnostic?
    experiment_definition.experiment_type == ExperimentDefinition::TYPE_DIAGNOSTIC
  end
  
  def calibration?
    experiment_definition.experiment_type == ExperimentDefinition::TYPE_CALIBRATION
  end

  def diagnostic_passed?
    diagnostic? && completion_status == "success" && analyze_status == "success"
  end

  def calibration_id
    if experiment_definition.guid == "thermal_consistency"
      return 1
    elsif experiment_definition.guid == "optical_cal" || experiment_definition.guid == "dual_channel_optical_cal_v2" ||
          experiment_definition.guid == "optical_test_dual_channel"
      return self.id
    else
      return read_attribute(:calibration_id)
    end
  end
  
  def standard_experiment_id=(val)
    write_attribute(:targets_well_layout_id, WellLayout.for_experiment(val).pluck(:id).first) if !val.blank?
  end
  
  def as_json(options={})
      {:id=>id,
       :guid=>experiment_definition.guid,
       :stages=>experiment_definition.protocol.stages.map {|stage|
        { :id=>stage.id,
          :name=>stage.name,
          :stage_type=>stage.stage_type,
          :num_cycles=>stage.num_cycles,
          :steps=>stage.steps.map { |step|
            {:id=>step.id, :name=>step.name, :hold_time=>step.hold_time, :ramp_id=>(step.ramp)? step.ramp.id : nil}
          }
        }
       }
      }
  end
  
  def as_csv
    CSV.generate do |csv|
      csv << ["id", "name", "status", "status_message", "created on", "run on"]
      csv << [id, name, completion_status, completion_message, created_at.iso8601, started_at.iso8601]
    end
  end
  
  protected
  
  def validate
    if targets_well_layout_id_changed? && !targets_well_layout_id_was.blank?
      if Target.joins("inner join targets_wells on targets_wells.target_id = targets.id").where(["targets.well_layout_id=? and targets_wells.well_layout_id=?", targets_well_layout_id_was, well_layout.id]).exists?
        errors.add(:targets_well_layout_id, "cannot be changed because targets are already linked")
      end
    end
  end
end
