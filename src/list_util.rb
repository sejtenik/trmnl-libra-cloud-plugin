class ListUtil

  # Filters an array, selecting a specified number of elements
  # with a bias towards the END of the array.
  #
  # @param source_array [Array] The original array to filter.
  # @param target_size [Integer] The desired number of elements in the result array.
  # @param power [Float] The exponent controlling the distribution bias.
  #                      Values > 1.0 increase the bias towards the end.
  #                      Value 1.0 would give (approximately) uniform sampling.
  #                      Value 2.0 (default) provides a strong end bias.
  # @return [Array] The filtered array, with elements sorted in their original order.
  # @author Gemini 2.5 Pro Experimental 03-25
  def self.filter_with_end_bias(source_array, target_size, power = 2.0)
    n = source_array.size
    k = target_size

    # Handle edge cases
    return [] if k <= 0 || n == 0
    # If target size is greater or equal, return a copy of the original array
    # truncated to k elements if k < n originally (though this case is handled by the main logic too)
    # or just the full array if k >= n.
    return source_array.take(k) if k >= n
    # If only one element is requested, return the last one
    return [source_array.last] if k == 1

    # --- Step 1: Generate initial "ideal" indices based on bias ---
    initial_indices = []
    (0...k).each do |i|
      normalized_pos = i / (k - 1.0)
      transformed_pos = normalized_pos ** power
      inverted_transformed_pos = 1.0 - transformed_pos
      # Calculate the ideal index (float), then round it.
      ideal_index = (inverted_transformed_pos * (n - 1.0)).round
      initial_indices << ideal_index
    end

    # --- Step 2: Resolve collisions to ensure exactly k unique indices ---
    final_indices = Array.new(k)
    used_indices = Set.new

    initial_indices.each_with_index do |current_index, i|
      resolved_index = current_index
      # Check if the current index is already used or if it's out of bounds initially
      # (though rounding should keep it in bounds unless n=0/1, handled above)
      if used_indices.include?(resolved_index) || !(0...n).include?(resolved_index)
        # Collision detected or index is somehow invalid (less likely with rounding).
        # Start searching for the nearest available index.
        offset = 1
        loop do
          # Check index + offset
          candidate_plus = current_index + offset
          if (0...n).include?(candidate_plus) && !used_indices.include?(candidate_plus)
            resolved_index = candidate_plus
            break
          end

          # Check index - offset
          candidate_minus = current_index - offset
          if (0...n).include?(candidate_minus) && !used_indices.include?(candidate_minus)
            resolved_index = candidate_minus
            break
          end

          offset += 1
          # Safety break (should not be needed if k <= n)
          raise "Could not find unique index, k=#{k}, n=#{n}" if offset > n
        end
      end
      # Mark the resolved index as used and store it
      used_indices.add(resolved_index)
      final_indices[i] = resolved_index
    end

    # --- Step 3: Sort the unique indices and retrieve elements ---
    # Sort the final indices to maintain original order in the output
    sorted_final_indices = final_indices.sort

    # Retrieve elements
    source_array.values_at(*sorted_final_indices)
  end

end