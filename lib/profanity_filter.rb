require "benchmark"

module ProfanityFilter
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def profanity_filter!(*attr_names)
      option = attr_names.pop[:method] if attr_names.last.is_a?(Hash)
      attr_names.each { |attr_name| setup_callbacks_for(attr_name, option) }
    end
    
    def profanity_filter(*attr_names)
      option = attr_names.pop[:method] if attr_names.last.is_a?(Hash)

      attr_names.each do |attr_name| 
        instance_eval do
          define_method "#{attr_name}_clean" do; ProfanityFilter::Base.clean(self[attr_name.to_sym], option); end      
          define_method "#{attr_name}_original"do; self[attr_name]; end
          alias_method attr_name.to_sym, "#{attr_name}_clean".to_sym
        end
      end
    end
    
    def setup_callbacks_for(attr_name, option)
      before_validation do |record|
        record[attr_name.to_sym] = ProfanityFilter::Base.clean(record[attr_name.to_sym], option)
      end
    end
  end
  
  class Base
    cattr_accessor :replacement_text, :dictionary_file, :dictionary
    @@replacement_text = '@#$%'
    @@dictionary_file  = File.join(File.dirname(__FILE__), '../config/dictionary.yml')
    @@dictionary       = YAML.load_file(@@dictionary_file)

    class << self
      def clean(text, replace_method = '')
        return text if text.blank?
        text.split(/(\W)/).collect{|word| replace_method == 'dictionary' ? clean_word_dictionary(word) : clean_word_basic(word)}.join
      end
      
      def profane?(text)
          return false if text.blank?
          text.split(/(\W)/).collect{|word| return true if dictionary.include?(word.downcase.squeeze)}          
          return false
      end

      def clean_word_dictionary(word)
        dictionary.include?(word.downcase.squeeze) && word.size > 2 ? dictionary[word.downcase.squeeze] : word
      end

      def clean_word_basic(word)
        dictionary.include?(word.downcase.squeeze) && word.size > 2 ? replacement_text : word
      end
    end
  end
end

module Validations
  def self.included(base)
    base.extend Validations::ClassMethods
  end

  module ClassMethods
    def validates_no_profanity(fields, args = {})
        msg = args[:message] || "contains profanity"

        validates_each fields do |model, attr, val|
            if !val.blank? and ProfanityFilter::Base.profane?(val) then
                model.errors.add(attr, msg)
            end
        end
    end        
  end
end

class ActiveRecord::Base
  # add in the extra validations created above
  include Validations
end

