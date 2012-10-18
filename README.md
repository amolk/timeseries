# Timeseries

Store timeseries data to mongodb and query by range and granularity

## Installation

Add this line to your application's Gemfile:

    gem 'timeseries'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install timeseries

## Usage

    class SampleModel
      # timeseries gem works with MongoMapper documents
      include MongoMapper::Document

      # include timeseries
      include Timeseries

      # define any fields
      key :sample_field, String

      # define timeseries
      timeseries([:name => :price, :config => {'resolution' => 'day'}])

      def price
        self.timeseries[0]
      end
    end


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
