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
      @timeseries.append([Time.utc(2000, 1, 1), 1000], @stock)
      @stock.save

      @timeseries = Stock.first.price
      @timeseries.series[Timeseries::RAW].items.should == [[Time.utc(2000, 1, 1), 1000]]
    end

    it "should make item the current item" do
      @timeseries.append([Time.utc(2000, 1, 1), 1000], @stock)
      @stock.save

      @timeseries = Stock.first.price
      @timeseries.last.should == [Time.utc(2000, 1, 1), 1000]
    end

    it "should append items only in chronological order" do 
      @timeseries.append([Time.utc(2000, 1, 1), 1000], @stock)
      @timeseries.series[Timeseries::RAW].items.count.should == 1

      @timeseries.append([Time.utc(2000, 1, 2), 2000], @stock)
      @timeseries.series[Timeseries::RAW].items.count.should == 2

      expect {@timeseries.append([Time.utc(1999, 1, 2), 100], @stock)}.to raise_error
      @timeseries.series[Timeseries::RAW].items.count.should == 2
    end

    context "daily series" do
      before do
        @timeseries.append([Time.utc(2000, 1, 1, 6), 1000], @stock)
        @timeseries.append([Time.utc(2000, 1, 1, 12), 2000], @stock)
        @timeseries.append([Time.utc(2000, 1, 2, 12), 3000], @stock)
        @timeseries.append([Time.utc(2000, 1, 2, 14), 4000], @stock)
        @timeseries.append([Time.utc(2000, 1, 3, 12), 5000], @stock)
        @timeseries.append([Time.utc(2000, 1, 7, 12), 6000], @stock)
        @stock.save

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
        @timeseries.append([Time.utc(2000, 1, 1, 6), 1000], @stock)
        @timeseries.append([Time.utc(2001, 1, 1, 12), 2000], @stock)
        @timeseries.append([Time.utc(2001, 1, 2, 12), 3000], @stock)
        @timeseries.append([Time.utc(2002, 1, 2, 14), 4000], @stock)
        @stock.save

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

    context "cached value fields" do
      before do
        @timeseries.append([Time.utc(2000, 1, 1, 1), 100], @stock)
        @timeseries.append([Time.utc(2000, 1, 1, 4), 1000], @stock)
        @timeseries.append([Time.utc(2000, 1, 1, 5), 1000], @stock)
        @timeseries.append([Time.utc(2000, 1, 1, 6), 1000], @stock)
        @stock.save
        @stock = Stock.first
      end

      it "*_first_time" do
        @stock.price_first_time.should == Time.utc(2000, 1, 1, 1)
      end
      it "*_first_value" do
        @stock.price_first_value.should == 100
      end

      it "*_current_time" do
        @stock.price_current_time.should == Time.utc(2000, 1, 1, 6)
      end
      it "*_current_value" do
        @stock.price_current_value.should == 1000
      end
    end
  end

  context "query" do
    before do
      @timeseries = @stock.price
      @timeseries.append([Time.utc(2000, 1, 1, 1), 100], @stock)
      @timeseries.append([Time.utc(2001, 1, 1, 4), 1000], @stock)
      @timeseries.append([Time.utc(2002, 1, 1, 5), 10000], @stock)
      @timeseries.append([Time.utc(2003, 1, 1, 6), 100000], @stock)
      @stock.save
      @stock = Stock.first
    end

    it "all raw entries" do
      @timeseries.query({:resolution => Timeseries::RAW, :from => 0, :to => 0}).count.should == 4
    end

    it "all year entries" do
      @timeseries.query({:resolution => Timeseries::YEAR, :from => 0, :to => 0}).count.should == 3
    end

    it "all month entries" do
      @timeseries.query({:resolution => Timeseries::MONTH, :from => 0, :to => 0}).count.should == 36
    end

    it "all week entries" do
      @timeseries.query({:resolution => Timeseries::WEEK, :from => 0, :to => 0}).count.should == 157
    end

    it "all day entries" do
      @timeseries.query({:resolution => Timeseries::DAY, :from => 0, :to => 0}).count.should == 1096
    end

    context "date range" do
      pending "not implemented yet" do
        before do
          @params = {:resolution => Timeseries::MONTH, :from => 0, :to => 0}
        end

        context "from and to" do
          it "from after to" do
            @params[:from] = Time.utc(2000, 1, 1).to_i
            @params[:to]   = Time.utc(1999, 1, 1).to_i
            expect { @timeseries.query(@params) }.to raise_error
          end

          it "range inside available data" do
            @params[:from] = Time.utc(2001, 1, 1).to_i
            @params[:to]   = Time.utc(2002, 1, 1).to_i
            @timeseries.query(@params).count.should == 12
          end

          it "from before available data" do
            @params[:from] = Time.utc(1999, 1, 1).to_i
            @params[:to]   = Time.utc(2002, 1, 1).to_i
            @timeseries.query(@params).count.should == 24
          end

          it "to after available data" do
            @params[:from] = Time.utc(2001, 1, 1).to_i
            @params[:to]   = Time.utc(2005, 1, 1).to_i
            @timeseries.query(@params).count.should == 24
          end

          it "from after available data (range completely outside)" do
            @params[:from] = Time.utc(2004, 1, 1).to_i
            @params[:to]   = Time.utc(2005, 1, 1).to_i
            @timeseries.query(@params).count.should == 0
          end

          it "to before available data (range completely outside)" do
            @params[:from] = Time.utc(1996, 1, 1).to_i
            @params[:to]   = Time.utc(1998, 1, 1).to_i
            @timeseries.query(@params).count.should == 0
          end

        end

        context "only to" do
          it "to inside available data" do
            @params[:from] = 0
            @params[:to]   = Time.utc(2002, 1, 1).to_i
            @timeseries.query(@params).count.should == 12
          end

          it "to after available data (all data)" do
            @params[:from] = 0
            @params[:to]   = Time.utc(2005, 1, 1).to_i
            @timeseries.query(@params).count.should == 36
          end

          it "to before availble data (no data)" do
            @params[:from] = 0
            @params[:to]   = Time.utc(1999, 1, 1).to_i
            @timeseries.query(@params).count.should == 0
          end
        end

        context "only from" do
          it "from inside available data" do
            @params[:from] = Time.utc(2002, 1, 1).to_i
            @params[:to]   = 0
            @timeseries.query(@params).count.should == 12
          end

          it "from after available data (no data)" do
            @params[:from] = Time.utc(2005, 1, 1).to_i
            @params[:to]   = 0
            @timeseries.query(@params).count.should == 0
          end

          it "from before availble data (all data)" do
            @params[:from] = Time.utc(1999, 1, 1).to_i
            @params[:to]   = 0
            @timeseries.query(@params).count.should == 36
          end
        end
      end
    end
  end
end