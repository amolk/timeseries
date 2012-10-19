require "timeseries/version"
require "mongo_mapper"

module Timeseries
  RESOLUTIONS = [:raw, :year, :month, :week, :day]
  RAW = 0
  YEAR = 1
  MONTH = 2
  WEEK = 3
  DAY = 4

  class ResolutionProcessorYear
    def self.interval
      1.year
    end

    def self.record_time(previous_time)
      Time.utc(previous_time.year)
    end

    def self.next_record_time(t)
      t + self.interval
    end
  end

  class ResolutionProcessorMonth
    def self.interval
      1.month
    end

    def self.record_time(previous_time)
      Time.utc(previous_time.year, previous_time.month)
    end

    def self.next_record_time(t)
      t + self.interval
    end
  end

  class ResolutionProcessorWeek
    def self.interval
      7.days
    end

    def self.record_time(previous_time)
      Time.utc(previous_time.year, previous_time.month, previous_time.day) - previous_time.wday.days
    end

    def self.next_record_time(t)
      t + self.interval
    end
  end

  class ResolutionProcessorDay
    def self.interval
      1.day
    end

    def self.record_time(previous_time)
      Time.utc(previous_time.year, previous_time.month, previous_time.day)
    end

    def self.next_record_time(t)
      t + self.interval
    end
  end

  ResolutionProcessors = [nil, ResolutionProcessorYear, ResolutionProcessorMonth, ResolutionProcessorWeek, ResolutionProcessorDay]

  class Series
    include MongoMapper::EmbeddedDocument
    belongs_to :series_collection

    key :items, Array

    def as_full_json
      items.as_json
    end
  end

  class Timeseries
    include MongoMapper::Document
    belongs_to :chronological, polymorphic: true
    after_validation :create_series

    key :name
    key :config, Hash
    key :last, Array
    many :series, order: :_id, class_name: 'Timeseries::Series', as: 'series_collection', dependent: :destroy

    # after_destroy :remove_series_documents
    def initialize(name, config = {})
      self.name = name
      self.config = {'resolution' => :day}.merge(config || {})
    end

    def create_series
      if self.series == nil || self.series.length == 0
        self.series = []
        #create one series per resolution we want to track
        (RAW..DAY).each{ |r|
          self.series << Series.new

          break if r == self.config['resolution']
        }
      end
    end

    def << (item)
      if (self.last && self.last[0] && self.last[0] >= item[0])
        raise "Add time series items in chronological order"
      end

      self.series[RAW].items << item

      # find out boundary and see if the new item crossed the boundary
      if (self.last && self.last[0]) 
        previous_time = self.last[0]
        previous_value = self.last[1]

        next_time = item[0]
        next_value = item[1]

        (1..RESOLUTIONS.length-1).each {|resolution|
          s = self.series[resolution]
          break if s == nil

          interval_processor = ResolutionProcessors[resolution]
          next unless interval_processor

          record_time = interval_processor.record_time(previous_time) + interval_processor.interval
          records_added = false

          while (record_time <= next_time)
            record_value = next_value - ((next_time - record_time)*(next_value-previous_value)) / (next_time - previous_time)
            s.items << [record_time - interval_processor.interval, record_value.to_i]

            record_time = interval_processor.next_record_time(record_time)
            records_added = true
          end
        }
      end

      self.last = item
      if chronological.send("#{self.name}_first_time") == nil
        chronological.send("#{self.name}_first_time=", item[0])
        chronological.send("#{self.name}_first_value=", item[1])
      end

      chronological.send("#{self.name}_current_time=", item[0])
      chronological.send("#{self.name}_current_value=", item[1])
      chronological.save
    end

    def query(params)
      resolution = DAY
      if (params[:resolution] != nil)
        resolution = Integer(params[:resolution])
      end

      self.series[resolution].items.as_json
    end

    def as_full_json
      j = self.as_json
      j[:series] = []
      self.series.each{|s|
        j[:series] << s.as_full_json
      }
      j
    end
  end

  def create_timeseries(list)
    list.each { |item|
      ts = Timeseries.new(item[:name], item[:config])
      ts.chronological = self
      ts.save!
    }
  end

  module ClassMethods
    def timeseries(list)
      many :timeseries, order: :_id, class_name: 'Timeseries::Timeseries', as: 'chronological', dependent: :destroy

      list.each{|item|
        key "#{item[:name]}_first_value", Integer
        key "#{item[:name]}_first_time", Time
        key "#{item[:name]}_current_value", Integer
        key "#{item[:name]}_current_time", Time
      }

      after_create lambda {create_timeseries(list)}
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

end
