# encoding: utf-8

require 'chord'

require 'c_chords'
require 'c_sharp_chords'
require 'd_chords'
require 'd_sharp_chords'
require 'e_chords'
require 'f_chords'
require 'f_sharp_chords'
require 'g_chords'
require 'g_sharp_chords'
require 'a_chords'
require 'a_sharp_chords'
require 'b_chords'

require 'text'
require 'section'

require 'tuning'
include Tuning

module Chordy
  $line_length = 8
  $separator_length = 40
  $chords = []
  $auto = true
  $tuning = tuning_6_standard.map { |e| e.capitalize  }
  $reverse = false

  # printing delimiters
  $chord_space = "-"
  $half_length_delimiter = "|"
  $start_delimiter = "["
  $end_delimiter = "]"

  def auto a=true
    $auto = if a then true else false end
  end

  def no_auto
    auto false
  end

  def line_length a
    if a.instance_of? Fixnum
      $line_length = a
      do_print
    else
      puts "Invalid length"
    end
  end

  def clear
    $chords = []
    do_print
  end

  # TODO document + examples

  def set_tuning_with_padding tuning
    longest_tuning_str_length = tuning.max.length
    $tuning = tuning.map { |e| e.capitalize.rjust(longest_tuning_str_length) }
    
    $chords = $chords.each { |e| e.pad_or_trim $tuning.length, true }
  end

  def tune new_tuning
    to_do_print = false
    strings = [6, 7, 8]

    if new_tuning.is_a? Array
      if strings.include? new_tuning.length
        set_tuning_with_padding new_tuning
        to_do_print = true
      else
        puts "Invalid tuning; only " + strings.join(",") + " strings are allowed" 
      end
    else
      if is_tuning? new_tuning.to_s
        new_tuning = eval("#{new_tuning}")
        set_tuning_with_padding new_tuning
        to_do_print = true
      else
        puts "Unknown or invalid tuning"
      end
    end

    if to_do_print
      do_print
    end
  end

  def check_sharp_or_flat_chord chord_name
    chord = chord_name.capitalize
    sharp_re = /!$/
    flat_re = /_$/

    if sharp_re =~ chord
      chord = chord.gsub(sharp_re, "Sharp")
    elsif flat_re =~ chord
      chord = chord.gsub(flat_re, "Flat")
    end

    chord
  end

  def check_chord_class chord_name
    eval("defined?(#{chord_name}) == 'constant' and #{chord_name}.class == Class")
  end

  def play chords, chord_type=:major
    chord = nil
    begin
      if chords.instance_of? Array
        chord = Chord.new(chords, $tuning.length)
      else
        chord_name = chords.to_s
        if !check_chord_class chord_name
          chord_name = check_sharp_or_flat_chord chord_name
        end

        chord_init = "#{chord_name}.new :#{chord_type}, #{$tuning.length}"
        chord = eval(chord_init)
      end

      $chords.push chord
      do_print
    rescue NameError => ne
      puts "Unknown chord or chord type"
      puts ne.message
    rescue Exception => e
      puts e.class.to_s
      puts e.message
    end

    chord
  end

  def text text
    $chords.push Text.new(text)
    do_print
  end

  def section title=""
    $chords.push Section.new(title, $separator_length)
    do_print
  end

  def separator 
    section
  end

  def do_print
    if $auto
      print_chords
    end
  end

  def print_chords
    lines_to_print = []
    chord_index = 0
    chords_in_section = 0
    tuning_length = $tuning.length
    is_done = false
    is_new_line = true
    is_even_line_length = ($line_length % 2) == 0
    is_next_chord_section_or_text = false
    to_print_start_chords = false
    to_skip_end_strings = false

    while !is_done
      if is_new_line or to_print_start_chords
        if $chords[chord_index].is_a? Chord
          start_strings = Chord.start_of_strings $tuning, $start_delimiter
          start_strings.each { |s| lines_to_print.push s }
        end
        to_print_start_chords = false
        is_new_line = false
      end

      last_chord_lines = lines_to_print.last(tuning_length + 1)
      curr_chord = $chords[chord_index]
      if curr_chord.is_a? Chord
        last_chord_lines.each_with_index do |line,i|
          if i == tuning_length
            line << curr_chord.print_flag
          else
            line << curr_chord.print_string_at(i, $chord_space)
          end
        end
        
        chords_in_section = chords_in_section + 1
        to_skip_end_strings = false
      elsif ($chords[chord_index].is_a? Text) or ($chords[chord_index].is_a? Section)
        lines_to_print.push $chords[chord_index].to_s
        to_skip_end_strings = true
        chords_in_section = 0
        
        if $chords[chord_index + 1].is_a? Chord
          to_print_start_chords = true
        end
      end

      chord_index = chord_index + 1
      if ($chords[chord_index].is_a? Text) or ($chords[chord_index].is_a? Section)
        is_next_chord_section_or_text = true
      else
        is_next_chord_section_or_text = false
      end
      
      if ((chords_in_section % $line_length) == 0) or (chord_index == $chords.length) or is_next_chord_section_or_text
        if to_skip_end_strings
          to_skip_end_strings = false
        else
          end_strings = Chord.end_of_strings $tuning, $end_delimiter
          last_chord_lines.each_with_index do |line, i|
            line << end_strings[i]
          end
        end

        # start the next actual line
        lines_to_print.push ""
        is_new_line = true
      elsif (chords_in_section % $line_length) == ($line_length / 2) and is_even_line_length
        last_chord_lines.each_with_index do |line, i| 
          line << Chord.print_half_length_string_at(i, $tuning, $half_length_delimiter, $chord_space)
        end
      end
      
      if is_next_chord_section_or_text
        is_new_line = false
      end

      if chord_index >= $chords.length
        is_done = true
      end
    end

    # print the buffer
    lines_to_print.each { |l| puts l }
    nil
  end

  Chord::CHORD_FLAGS.each_with_index do |name,i|
    eval <<-ENDOFEVAL
    def #{name}
      saved_auto = $auto
      saved_chord_index = $chords.length
      $auto = false
      begin
        chord = yield if block_given?
        
        num_new_chords = $chords.length - saved_chord_index
        $chords.last(num_new_chords).each { |c| c.send :#{name} }
      rescue Exception => e
        puts e.class.to_s
        puts e.message
      end

      $auto = saved_auto
      do_print
      chord
    end
    ENDOFEVAL

    if name != "dont_play"
      eval <<-ENDOFEVAL
      def play_#{name} chords, chord_type=:major
        #{name} { play chords, chord_type }
      end
      ENDOFEVAL
    end
  end

  Chord.short_chords.values.each do |s|
    short_chord_name = s.to_s
    eval <<-ENDOFEVAL
      def #{short_chord_name}
        :#{s}
      end
      ENDOFEVAL
  end
end

include Chordy
