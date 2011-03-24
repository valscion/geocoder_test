require 'test_helper'

class VenueTest < ActiveSupport::TestCase

  def setup
    Geocoder::Configuration.cache = nil
  end

  # --- geocoding ---

  test "fetch coordinates" do
    v = Venue.new(
      :name => "Madison Square Garden",
      :address => "4 Penn Plaza, New York, NY"
    )
    v.fetch_coordinates
    assert_not_nil v.latitude
    assert_not_nil v.longitude
    assert (v.latitude - 40.75).abs < 0.01
    assert (v.longitude - -73.99).abs < 0.01
  end

  test "lookup with blank address" do
    v = Venue.new(
      :name => "Haunted House",
      :address => ""
    )
    assert_nothing_raised do
      v.fetch_coordinates
    end
  end

  test "lookup with bad address" do
    v = Venue.new(
      :name => "Haunted House",
      :address => ", , , "
    )
    assert_nothing_raised do
      v.fetch_coordinates
    end
  end


  # --- distance ---

  test "distance of found points" do
    distance = 9
    nearbys = Venue.near(hempstead_coords, 15)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (distance - nikon.distance).abs < 1,
      "Distance should be close to #{distance} miles but was #{nikon.distance}"
  end


  # --- bearing ---

  test "bearing (linear) of found points" do
    bearing = 137
    nearbys = Venue.near(hempstead_coords, 15, :bearing => :linear)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (bearing - nikon.bearing).abs < 2,
      "Bearing should be close to #{bearing} degrees but was #{nikon.bearing}"
  end

  test "bearing (spherical) of found points" do
    bearing = 144
    nearbys = Venue.near(hempstead_coords, 15, :bearing => :spherical)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (bearing - nikon.bearing).abs < 2,
      "Bearing should be close to #{bearing} degrees but was #{nikon.bearing}"
  end

  test "don't calculate bearing" do
    nearbys = Venue.near(hempstead_coords, 15, :bearing => false)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert_raises(NoMethodError) { nikon.bearing }
  end


  # --- near ---

  test "finds venues near a point" do
    assert Venue.near(hempstead_coords, 15).include?(venues(:nikon))
  end

  test "don't find venues not near a point" do
    assert !Venue.near(hempstead_coords, 5).include?(venues(:forum))
  end

  test "find all venues near another venue" do
    assert venues(:nikon).nearbys(40).include?(venues(:beacon))
    assert venues(:beacon).nearbys(40).include?(venues(:nikon))
  end

  test "don't find venues not near another venue" do
    assert !venues(:nikon).nearbys(10).include?(venues(:forum))
    assert !venues(:forum).nearbys(10).include?(venues(:beacon))
  end

  test "don't include self in nearbys" do
    assert !venues(:nikon).nearbys(5).include?(venues(:nikon))
  end


  # --- cache ---

  test "new result stored on cache miss" do
    cache_stores.each do |store|
      Geocoder::Configuration.cache = store
      query = "4893 Clay St, San Francisco, CA"
      url   = Geocoder.send(:lookup).send(:query_url, query, false)
      cache = Geocoder.cache
      cache.expire(url)
      assert_nil cache[url]
      Geocoder.search(query)
      assert_not_nil cache[url]
      cache.expire(url)
    end
  end

  test "cache hit" do
    Geocoder::Configuration.lookup = :geocoder_ca # fake result format
    cache_stores.each do |store|
      Geocoder::Configuration.cache = store
      query = "4893 Clay St, San Francisco, CA"
      url   = Geocoder.send(:lookup).send(:query_url, query, false)
      cache = Geocoder.cache
      # manually set weird cache content
      cache[url] = "test({'latt':'4.44','longt':'5.55'});"
      result = Geocoder.search(query).first
      assert_equal "4.44", result.latitude.to_s
      assert_equal "5.55", result.longitude.to_s
      cache.expire(url)
    end
  end

  test "cache expiration" do
    cache_stores.each do |store|
      cache = Geocoder.cache
      url   = "http://a"
      cache[url] = "blah blah blah"
      assert cache.send(:urls).include?(url)
      cache.expire(url)
      assert !cache.send(:urls).include?(url)
    end
  end

  test "full cache expiration" do
    cache_stores.each do |store|
      cache = Geocoder.cache
      cache["http://a"] = "blah blah blah"
      cache["http://b"] = "blah blah blah"
      cache.expire(:all)
      assert_equal 0, cache.send(:keys).size
    end
  end


  # --- near scope options ---

  test "select options" do
    forum = venues(:forum)
    venues = Venue.near(hollywood_coords, 20,
      :select => "*, latitude * longitude AS junk")
    assert venues.first.junk.to_f - (forum.latitude * forum.longitude) < 0.1
  end

  # TODO: test limit, order, offset, exclude, and units arguments


  private # ------------------------------------------------------------------

  ##
  # Array of supported cache stores to test.
  #
  def cache_stores
    [{}, Redis.new]
  end

  ##
  # Coordinates of Hempstead, Long Island, NY, about 8 miles from Jones Beach.
  #
  def hempstead_coords
    [40.7062128, -73.6187397]
  end

  ##
  # Coordinates of Hollywood, CA, about 10 miles from The Great Western Forum.
  #
  def hollywood_coords
    [34.09833, -118.32583]
  end
end
