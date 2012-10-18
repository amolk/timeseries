require 'spec_helper'

class Stock
  include MongoMapper::Document
  include Timeseries

  key :symbol, String
  timeseries([:name => :price, :config => {'resolution' => 'day'}])

  def price
    self.timeseries[0]
  end
end

describe Timeseries do
  before do
    Stock.collection.remove
    Stock.create({:symbol => 'AAPL'})
    @stock = Stock.first
  end

  context "test document" do
    it "should exist" do
      Stock.count.should == 1
    end

    it "should have a timeseries field" do
      @stock.price.should_not == nil
    end
  end

  context "timeseries field" do
    before do
      @price = @stock.price
    end

    it "should have a name" do
      @price.name.should == :price
    end

    it "should have configuration" do
      @price.config.should_not == nil
    end

    context "configuration" do
      it "should have default resolution day" do
        @price.config['resolution'].should == 'day'
      end
    end
  end

  context "append time series items" do
    before do
      @timeseries = @stock.price
    end

    it "should add item to the :raw series" do
      @timeseries << [Time.utc(2000, 1, 1), 1000]
      @timeseries.save

      @timeseries = Stock.first.price
      @timeseries.series[Timeseries::RAW].items.should == [[Time.utc(2000, 1, 1), 1000]]
    end

    it "should make item the current item" do
      @timeseries << [Time.utc(2000, 1, 1), 1000]
      @timeseries.save

      @timeseries = Stock.first.price
      @timeseries.last.should == [Time.utc(2000, 1, 1), 1000]
    end

    it "should append items only in chronological order" do 
      @timeseries << [Time.utc(2000, 1, 1), 1000]
      @timeseries.save

      @timeseries = Stock.first.price
      @timeseries.series[Timeseries::RAW].items.count.should == 1

      @timeseries << [Time.utc(2000, 1, 2), 2000]
      @timeseries.save

      @timeseries = Stock.first.price
      @timeseries.series[Timeseries::RAW].items.count.should == 2

      expect {@timeseries << [Time.utc(1999, 1, 2), 100]}.to raise_error
      @timeseries.save

      @timeseries = Stock.first.price
      @timeseries.series[Timeseries::RAW].items.count.should == 2
    end

    context "daily series" do
      before do
        @timeseries << [Time.utc(2000, 1, 1, 6), 1000]
        @timeseries << [Time.utc(2000, 1, 1, 12), 2000]
        @timeseries << [Time.utc(2000, 1, 2, 12), 3000]
        @timeseries << [Time.utc(2000, 1, 2, 14), 4000]
        @timeseries << [Time.utc(2000, 1, 3, 12), 5000]
        @timeseries << [Time.utc(2000, 1, 7, 12), 6000]
        @timeseries.save

        @timeseries = Stock.first.price
        @daily_items = @timeseries.series[Timeseries::DAY].items
      end

      it "should add one item per complete day" do
        @daily_items.count.should == 6
        @daily_items[0][0].should == Time.utc(2000, 1, 1)
        @daily_items[5][0].should == Time.utc(2000, 1, 6)
      end

      it "should set interpolated value at the end of each day" do
        @daily_items.should == [
          [Time.utc(2000, 1, 1), 2500], 
          [Time.utc(2000, 1, 2), 4454], 
          [Time.utc(2000, 1, 3), 5125], 
          [Time.utc(2000, 1, 4), 5375], 
          [Time.utc(2000, 1, 5), 5625], 
          [Time.utc(2000, 1, 6), 5875]
        ]
      end
    end

    context "yearly series" do
      before do
        @timeseries << [Time.utc(2000, 1, 1, 6), 1000]
        @timeseries << [Time.utc(2001, 1, 1, 12), 2000]
        @timeseries << [Time.utc(2001, 1, 2, 12), 3000]
        @timeseries << [Time.utc(2002, 1, 2, 14), 4000]
        @timeseries.save

        @timeseries = Stock.first.price
        @items = @timeseries.series[Timeseries::YEAR].items
      end

      it "should add one item per complete year" do
        @items.count.should == 2
        @items[0][0].should == Time.utc(2000, 1, 1)
        @items[1][0].should == Time.utc(2001, 1, 1)
      end

      it "should set interpolated value at the end of each year" do
        @items.should == [
          [Time.utc(2000, 1, 1), 1998], 
          [Time.utc(2001, 1, 1), 3995]
        ]
      end

      it "should set interpolated values for all days" do
        items = @timeseries.series[Timeseries::DAY].items
        items.count.should == 732
      end

      it "should set interpolated values for all weeks" do
        items = @timeseries.series[Timeseries::WEEK].items
        items.count.should == 105
      end

      it "should set interpolated values for all months" do
        items = @timeseries.series[Timeseries::MONTH].items
        items.count.should == 24
      end

    end

  end

end