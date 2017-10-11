#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'pathname'
require 'digest'
require 'color'

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
  opts.on("-f", "--foreground STRING or HEX", String, "Color of bar.") do |color|
    $options[:foreground] = Color::RGB.extract_colors(color)[0]
  end
  opts.on('-b', '--background STRING or HEX', String, "Color of background.") do |color|
    $options[:background] = Color::RGB.extract_colors(color)[0]
  end 
  opts.on('-B', '--bar-background STRING or HEX', String, "Color of the un-used part of the bar.") do |color|
    $options[:barBackground] = Color::RGB.extract_colors(color)[0]
  end
  opts.on("-W", "--width WIDTH", Integer, "Width of window on screen.") do |width|
    $options[:width] = width
  end
  opts.on("-H", "--height HEIGHT", Integer, "Height of window on screen.") do |height|
    $options[:height] = height
  end
  opts.on('-i', '--icon PATH', String, "Path to icon.") do |icon|
    $options[:icon] = icon
  end
  opts.on('-c', '--caption', 'Caption for the window') do |caption|
    $options[:caption] = caption
  end
  opts.on("--description STRING", String, "Description for bar. Should be unique if provided.") do |desc|
    $options[:description] = desc
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
#a unique identifier
hash = Digest::MD5.new.update($options.inspect).base64digest
pipePath = Pathname.new('/tmp/percent-bar-' + hash)


## Create Pipe or write to it
if pipePath.pipe?
  pipePath.open('w') { |file| file.write(ARGV[0])}
  exit
else system('mkfifo ' + pipePath.to_s) end

# Start handling of drawing window
require 'gosu'
require 'thread'

# Default arguments
$options[:delay] = 2 if not $options.has_key? :delay
$options[:height] = 150 if not $options.has_key? :height
$options[:width] = $options[:height] / 5 if not $options.has_key? :width
$options[:background] = Color::RGB.by_name("Black") if not $options.has_key? :background
$options[:foreground] = Color::RGB.by_name("White") if not $options.has_key? :foreground
$options[:barBackground] = $options[:background] if not $options.has_key? :barBackground

def colorToGosu(rgb)
  return Gosu::Color.argb(255, rgb.red, rgb.green, rgb.blue)
end

$options[:background] = colorToGosu($options[:background])
$options[:foreground] = colorToGosu($options[:foreground])
$options[:barBackground] = colorToGosu($options[:barBackground])

$barwidth = $options[:width] * 3 / 5
$barX = $options[:width] / 5
$padding = $barX

$mutex = Mutex.new
$percentMutex = Mutex.new


def bound(val)
  return [[val, 0].max, 100].min / 100
end

def myheight(val)
  return ($options[:height] - ($padding * 2)) * bound(val)
end

class BarWindow < Gosu::Window
  def initialize
    super $options[:width], $options[:height]
    self.caption = "Percent bar"
    @font = Gosu::Font.new(20)
  end

  def update
    # ...
  end
  
  def draw
    $percentMutex.synchronize do
      Gosu.draw_rect(0,0,$options[:width],$options[:height],$options[:background])
      Gosu.draw_rect($barX.to_f, $padding, $barwidth.to_f,
                     ($options[:height] - ($padding * 2)),
                     $options[:barBackground])
      Gosu.draw_rect($barX.to_f,
                     $options[:height].to_f - $padding - myheight($percent),
                     $barwidth.to_f, myheight($percent.to_f), $options[:foreground])
    end
  end

  def button_down(id)
    super
  end
end

#show window and fork to new thread
$windowThread = Thread.new {BarWindow.new.show}

# Clean up pipe
at_exit { system("rm -f " + pipePath.to_s)}

def timer
  if $options[:delay] >= 0
    sleep $options[:delay]
    $mutex.synchronize {
        $windowThread.kill
        exit
    }
  end
end

$timerThread = Thread.new {timer()}

loopThread = Thread.new do
  loop do
    input = pipePath.open('r')
    a = input.gets
    $percentMutex.synchronize do
      $percent = a.to_f
    end

    $timerThread.kill
    $timerThread = Thread.new {timer()}
    input.close
  end
end

$windowThread.join
