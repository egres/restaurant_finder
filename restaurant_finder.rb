module RestaurantHelper

  # Returns all combinations of numbers from 'numbers' array which when bitwise-or'ed together result in 'target'.
  # 'target' is binary encoding of items array where every item's bit is set to 1 to represent its presence.
  # e.g. user input of 'fish_sandwich milkshake fries' corresponds to a target number of 0b111.
  # this is useful when we are looking for all combinations of combo meals which, combined together,
  # satisfy our desired list of food items, i.e., considering above example, '5, 5.00, fish_sandwich, coke, milkshake, apple_pie'
  # in the csv entry would correspond to 0b110 with 1's representing presence of fish_sandwich and milkshake and 0
  # signifying absence of fries. Likewise, an entry with the same restaurant id (5 here)
  # of '5, 4.36, coffee, fries, fish_sandwich, ice_cream' would be encoded as 0b101. If we bitwise or 0b110 and 0b101,
  # we get 0b111, which is the target combination even though fish_sandwich is repeated and there are other items, we
  # don't care as the cheapest combination would still get us the desired result. And once we a collection of all
  # combinations of entries that satisfy the list of food items that we are looking for, it is easy to choose the cheapest one.
  def subset_bitwise_or(numbers, target)
    return [] if numbers.inject(:|).to_i < target #no need to run expensive recursion if no combinations satisfy target number
    # the recursion starts with an empty list as partial solution.
    bitwiseor_recursive(numbers, target, [])
  end

  # Recursive part of subset_bitwise_or
  def bitwiseor_recursive(numbers, target, partial)
    # bitwise-or all the numbers in the partial array:
    result = partial.inject(:|).to_i

    return [partial] if result == target
    return [] if result > target # if we exceed target why bother to continue

    satisfying_sets = []
    numbers.each_with_index do |number, index|
      satisfying_set = bitwiseor_recursive(numbers[index+1..-1], target, partial + [number])
      satisfying_sets += satisfying_set unless satisfying_set.empty?
    end
    satisfying_sets
  end

  module_function :subset_bitwise_or, :bitwiseor_recursive
end

class RestaurantFinder
  include RestaurantHelper

  def self.find_cheapest(menu_filename, *desired_items)
    rf = self.new
    rf.find_cheapest(menu_filename, *desired_items)
  end

  def initialize
    @restaurants = {}
  end

  def find_cheapest(menu_filename, *desired_items)
    @desired_items = desired_items

    File.open(menu_filename, "r") do |infile|
      while (line = infile.gets)
        process_line(line)
      end
    end

    best_restaurant_with_price unless @restaurants.empty?
  end

  private

  # takes line string, validates its format, and extracts data populating restaurants hash and nested entries hashes
  def process_line(line)
    # skip current line unless in correct format:
    # all restaurant IDs are integers, all item names are lower case letters and underscores,
    # and the price is a decimal number, all separated by commas with any surrounding whitespace
    return unless line =~ /^\d+\s*,\s*\d+\.\d{2}\s*,\s*([a-z_]+\s*,\s*)*[a-z_]+$/
    entry_items = line.gsub(/\s+/,'').split(',')

    restaurant_id = entry_items.shift
    entry_price = entry_items.shift

    encoded_entry = encode_entry(entry_items)
    return unless encoded_entry > 0 #if encoded_entry equals 0 then no items matched the desired so why bother

    update_min_entry_price(restaurant_id, entry_price, encoded_entry)
  end

  # encodes desired item presence in a given entry as a binary number
  def encode_entry(entry_items)
    encoded_entry = 0b0
    @desired_items.each do |item|
      # treat encoded_entry as binary and shift left then add 1 if the requested item is among the entry items:
      encoded_entry *= 2
      encoded_entry += 1 if entry_items.include?(item)
    end
    encoded_entry
  end

  # changes minimum entry price per encoded entry if input entry_price is lower than the one currently
  # stored in the restaurant entries hash or creates a new entry if one doesn't' exist.
  def update_min_entry_price(restaurant_id, entry_price, encoded_entry)
    @restaurants[restaurant_id] ||= {}
    min_entry_price = @restaurants[restaurant_id][encoded_entry]
    if min_entry_price.nil? or (entry_price.to_f < min_entry_price.to_f)
      @restaurants[restaurant_id][encoded_entry] = entry_price
    end
  end

  # finds and returns the lowest price possible along with the corresponding restaurant id
  def best_restaurant_with_price
    min_price = nil
    restaurant_choice_id = nil
    # since we encode all entries with request_items.size number of bits,
    # we need to target 2^n-1 as result of bitwise or:
    target_number = 2**@desired_items.size - 1
    @restaurants.each_pair do |restaurant_id, entries|
      # find all satisfying entry combinations for current restaurant
      satisfying_combos = subset_bitwise_or(entries.keys, target_number)

      satisfying_combos.each do |complimenting_entries|
        # find total price by adding up the complimenting entry prices:
        total_price = complimenting_entries.map{|entry| entries[entry].to_f}.inject(:+)
        if min_price.nil? or min_price > total_price
          restaurant_choice_id = restaurant_id.to_i
          min_price = total_price
        end
      end
    end
    return restaurant_choice_id, min_price if min_price
  end
end

# following allows executing program from command line,
# comment out if not using from cl:
puts RestaurantFinder.find_cheapest(ARGV[0], *ARGV[1..-1]).to_s if ARGV.size > 1