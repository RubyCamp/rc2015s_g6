require 'dxruby'
require_relative 'ev3/ev3'

class Defence
  R_ARM_MOTOR = "A"
  L_ARM_MOTOR = "D"
  ELBOW_MOTOR = "C"
  PORT = "COM3"
  ARM_SPEED = 10
  OPEN_ARM_SPEED = 5
  CLOSE_ARM_SPEED = 15
  # DEGREES_CLAW = 5000
  # CLAW_POWER = 30

  attr_reader :distance

  def initialize
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
    @brick.connect
    @busy = false # 実行中には処理を受け付けないために
  end

  def open_left_arm(speed=ARM_SPEED)
    operate do
      @brick.reverse_polarity(L_ARM_MOTOR)
      @brick.start(speed, L_ARM_MOTOR)
    end
  end

  def close_left_arm(speed=ARM_SPEED)
    operate do
      @brick.run_forward(L_ARM_MOTOR)
      @brick.start(speed, L_ARM_MOTOR)
    end
  end

  def open_right_arm(speed=ARM_SPEED)
    operate do
      @brick.run_forward(R_ARM_MOTOR)
      @brick.start(speed, R_ARM_MOTOR)
    end
  end

  def close_right_arm(speed=ARM_SPEED)
    operate do
      @brick.reverse_polarity(R_ARM_MOTOR)
      @brick.start(speed, R_ARM_MOTOR)
    end
  end

  def open_elbow(speed=ARM_SPEED)
    operate do
      @brick.reverse_polarity(ELBOW_MOTOR)
      @brick.start(speed, ELBOW_MOTOR)
    end
  end

  def close_elbow(speed=ARM_SPEED)
    operate do
      @brick.run_forward(ELBOW_MOTOR)
      @brick.start(speed, ELBOW_MOTOR)
    end
  end

  def open_arms
    open_left_arm(OPEN_ARM_SPEED)
    sleep(2)
    stop

    open_right_arm(OPEN_ARM_SPEED)
    sleep(2.5)
    stop

    open_elbow(OPEN_ARM_SPEED)
    sleep(2)
    stop

  end

  def close_arms
    close_left_arm(CLOSE_ARM_SPEED)
    close_right_arm(CLOSE_ARM_SPEED)
    sleep(0.2)
    stop
  end

  # 動きを止める
  def stop
    @brick.stop(true, *all_motors)
    @brick.run_forward(*all_motors)
    @busy = false
  end

  # ある動作中は別の動作を受け付けないようにする
  def operate
    unless @busy
      @busy = true
      yield(@brick)
    end
  end

  # センサー情報の更新とキー操作受付
  def run
    open_left_arm if Input.keyDown?(K_J)
    close_left_arm if Input.keyDown?(K_H)
    open_right_arm if Input.keyDown?(K_F)
    close_right_arm if Input.keyDown?(K_G)
    open_elbow if Input.keyDown?(K_L)
    close_elbow if Input.keyDown?(K_K)
    stop if [K_J,K_H,K_F,K_G,K_L,K_K].all?{|key| !Input.keyDown?(key) }
  end

  # 終了処理
  def close
    stop
    @brick.clear_all
    @brick.disconnect
  end

  def arm_motors
    [L_ARM_MOTOR,R_ARM_MOTOR]
  end

  def all_motors
    [L_ARM_MOTOR,R_ARM_MOTOR,ELBOW_MOTOR]
  end

end

begin
  puts "starting..."
  font = Font.new(32)
  defence = Defence.new
  puts "connected..."

  # defence.open_arms
  # sleep(150)
  # defence.close_arms

  Window.loop do
    break if Input.keyDown?(K_SPACE)
    defence.run
    # defence.auto
    Window.draw_font(100, 200, "#{defence.distance.to_i}cm", font)
  end
rescue
  p $!
  $!.backtrace.each{|trace| puts trace}
# 終了処理は必ず実行する
ensure
  puts "closing..."
  defence.close
  puts "finished..."
end
