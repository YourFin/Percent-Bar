#!/usr/bin/env ruby
require 'gosu'
require 'thread'
mutex = Mutex.new


class BarWindow < Gosu::Window
  @barVal = 0
  def initialize
    super 640, 400
    self.caption = "Tutorial Game"
  end

  def setBarVal(input)
    @barval = input
  end
  
  def update
    # ...
  end
  
  def draw
    Gosu.draw_rect(200, 200, 100, 100, Gosu::Color::WHITE)
  end

  def button_down(id)
    if id == Gosu::KB_ESCAPE
      close
    elsif id == Gous::KD_UP
      super
    else
      super
    end
  end
end

# Create a named pipe at /tmp/percent-bar-$process id
pipePath = '/tmp/percent-bar-' + Process.pid.to_s
if system('mkfifo ' + pipePath)
  input = open(pipePath, "r+")
  puts input.gets
end

timerThread = Thread.new do
  sleep 1
  mutex.synchronize {
    puts 'done'
    exit
  }
end

window = BarWindow.new.show

input = open(pipePath, "r+")
loop do
  window.setBarVal input.gets.to_i
  mutex.synchronize {
    timerThread.kill
    timerThread = Thread.new do
      sleep 1
      mutex.synchronize {
        puts 'done'
        exit
      }
    end
  }
end
