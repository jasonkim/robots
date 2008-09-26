require "open-uri"
require "uri"
require "rubygems"
require "loggable"
class Robots
  include Loggable
  
  class ParsedRobots
    include Loggable
    
    def initialize(uri)
      io = open(URI.join(uri.to_s, "/robots.txt")) rescue nil
      if !io || io.content_type != "text/plain" || io.status != ["200", "OK"]
        io = StringIO.new("User-agent: *\nAllow: /\n")
      end

      @other = {}
      @disallows = {}
      @allows = {}
      agent = ""
      io.each do |line|
        next if line =~ /^\s*(#.*|$)/
        key, value = line.split(":")
        value.strip!
        case key
        when "User-agent":
          agent = to_regex(value)
        when "Allow":
          @allows[agent] ||= []
          @allows[agent] << to_regex(value)
        when "Disallow":
          @disallows[agent] ||= []
          @disallows[agent] << to_regex(value)
        else
          @disallows[key] ||= []
          @disallows[key] << value
        end
      end
      
      @parsed = true
    end
    
    def allowed?(uri, user_agent)
      return true unless @parsed
      allowed = true
      path = uri.request_uri
      debug "path: #{path}"
      
      @disallows.each do |key, value|
        if user_agent =~ key
          debug "matched #{key.inspect}"
          value.each do |rule|
            if path =~ rule
              debug "matched Disallow: #{rule.inspect}"
              allowed = false
            end
          end
        end
      end
      
      return true if allowed
      
      @allows.each do |key, value|
        if user_agent =~ key
          debug "matched #{key.inspect}"
          value.each do |rule|
            if path =~ rule
              debug "matched Allow: #{rule.inspect}"
              return true 
            end
          end
        end
      end
      
      return false
    end
    
    def other_values
      @other
    end
    
  protected
    
    def to_regex(pattern)
      pattern = Regexp.escape(pattern)
      pattern.gsub!(Regexp.escape("*"), ".*")
      Regexp.compile("^#{pattern}")
    end
  end
  
  def initialize(user_agent)
    @user_agent = user_agent
    @parsed = {}
  end
  
  def allowed?(uri)
    uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
    host = uri.host
    @parsed[host] ||= ParsedRobots.new(uri)
    @parsed[host].allowed?(uri, @user_agent)
  end
  
  def other_values(uri)
    uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
    host = uri.host
    @parsed[host] ||= ParsedRobots.new(uri)
    @parsed[host].other_values
  end
end