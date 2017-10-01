#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'pathname'
require 'digest'

$options = {}

parser = OptionParser.new do |opts|
  opts.banner = "Usage percent-bar PERCENT [OPTIONS]"
  opts.separator  ""
  opts.separator  "Options:"
  opts.on("-t","--timeout N", Float, "Time until bar closes automatically. <= 0 will not timeout") do |nn|
    $options[:delay] = nn
  end
  opts.on("--position x,y", Array, "Position on screen") do |pos|
    $options[:posX] = pos[0]
    $options[:posY] = pos[1]
  end
  opts.on("--size width,height", Array, "Size of window on screen") do |size|
    $options[:width] = size[0]
    $options[:height] = size[1]
  end
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end.parse!

## Validate input
def invalidArguments()
  puts "Invalid arguments; try 'percent-bar --help' for help"
  exit
end

if ARGV.length != 1
  invalidArguments
end

begin
  $percent = ARGV[0].to_r
rescue TypeError
  invalidArguments
end

##Hash all the command line options to create
puts $options.inspect
#a unique identifier
hash = Digest::MD5.new.update($options.inspect).base64digest
pipePath = Pathname.new('/tmp/percent-bar-' + hash)

# Default arguments
$options[:delay] = 2 if not $options.has_key? :delay

## Create Pipe
if pipePath.pipe?
  pipePath.open('w') { |file| file.write(ARGV[0])}
  exit
else system('mkfifo ' + pipePath.to_s) end

# Start handling of drawing window
require 'gosu'
require 'thread'

$mutex = Mutex.new
$percentMutex = Mutex.new

class BarWindow < Gosu::Window
  def initialize
    super 640, 400
    self.caption = "Tutorial Game"
    @font = Gosu::Font.new(20)
  end

  def update
    # ...
  end
  
  def draw
    Gosu.draw_rect(200, 200, 100, 100, Gosu::Color::WHITE)
    $percentMutex.synchronize do
        Gosu.draw_rect(225, 210, 50, $percent.to_i, Gosu::Color::BLACK)
    end
  end

  def button_down(id)
    super
  end
end

puts "hello"

#show window and fork to new thread
$windowThread = Thread.new {BarWindow.new.show}

# Clean up pipe
at_exit { system("rm -f " + pipePath.to_s)}

def timer
  puts "timer"
  sleep $options[:delay]
  $mutex.synchronize {
    $windowThread.kill
    exit
  }
end

$timerThread = Thread.new {timer()}

loop do
  puts "loop"
  input = pipePath.open('r')
  a = input.gets
  $percentMutex.synchronize do
    $percent = a
  end

  $timerThread.kill
  $timerThread = Thread.new {timer()}
  input.close
end
