#!/usr/bin/env ruby
require 'rubygems'
require 'gosu'
require 'thread'
require 'optparse'
require 'pathname'
require 'Digest'

$options = Struct.new(:name)

OptionParser.new do |opts|
  opts.banner = "Usage percent-bar PERCENT [OPTIONS]"
  opts.separator  ""
  opts.separator  "Options:"
  opts.on("-t","--timeout N", Float, "Time until bar closes automatically. <= 0 will not timeout") do |nn|
    options[:delay] = nn
  end
  opts.on("--position x,y", Array, "Position on screen") do |pos|
    options[:posX] = pos[0]
    options[:posY] = pos[1]
  end
  opts.on("--size width,height", Array, "Size of window on screen") do |size|
    options[:width] = size[0]
    options[:height] = size[1]
  end
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
  end
end.parse!

#hash all the command line options to create
#a unique identifier
hash = Digest::MD5.new.update(opts.to_s).update(ARGV.to_s).base64digest
pipePath = Pathname.new('/tmp/percent-bar-' + hash)

if pipePath.pipe?
  pipePath.open('w') { |file| file.write(ARGV[0])}
  exit
else System('mkfifo ' + pipePath) end

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
        Gosu.draw_rect(225, 210, 50, $percent, Gosu::Color::BLACK)
    end
  end

  def button_down(id)
    if id == Gosu::KB_ESCAPE
      close
    else
      super
    end
  end
end

#show window and fork to new thread
$windowThread = Thread.new {BarWindow.new.show}

def timer
  puts "timer"
  sleep 5
  $mutex.synchronize {
    $windowThread.kill
    exit
  }
end

$timerThread = Thread.new {timer()}

loop do
  puts "loop"
  input = open(pipePath, "r+")
  a = input.gets
  $percentMutex.synchronize do
    $percent = a.to_i
  end

  $timerThread.kill
  $timerThread = Thread.new {timer()}
  input.close
end
