require 'dxruby'
require_relative 'ev3/ev3'

class Offence
  LEFT_WHEEL_MOTOR = "B"
  RIGHT_WHEEL_MOTOR = "C"
  LEFT_ARM_MOTOR = "A"
  RIGHT_ARM_MOTOR = "D"
  DISTANCE_SENSOR = "4"
  PORT = "COM3"
  WHEEL_SPEED = 50
  WHEEL_SLOW = 10
  ARM_UP_SPEED = 100
  ARM_UP_SLOW = 10
  ARM_DOWN_SPEED = 10
  DEGREES_CLAW = 5000
  CLAW_POWER = 30


  def initialize
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
    @brick.connect
    @busy = false # 実行中には処理を受け付けないために
    @grabbing = false # 掴んでいるかどうか状態を知るために。「投げる」の動作状態を確認するためにインスタンス変数使うのにも使えそう。
  end

  # 前進する。ここでモーターがどっち回転させたら前進するようになってるかといった部分を吸収する
  def run_forward(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(*wheel_motors)
      @brick.start(speed, *wheel_motors)
    end
  end

  # ゆっくり前進する
  def run_forward_slow(speed=WHEEL_SLOW)
    operate do
      @brick.reverse_polarity(*wheel_motors)
      @brick.start(speed, *wheel_motors)
    end
  end

  # バックする
  def run_backward(speed=WHEEL_SPEED)
    operate do
      @brick.start(speed, *wheel_motors)
    end
  end

  # ゆっくりバックする
  def run_backward_slow(speed=WHEEL_SLOW)
    operate do
      @brick.start(speed, *wheel_motors)
    end
  end

  # 右に回る
  def turn_right(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(RIGHT_WHEEL_MOTOR)
      @brick.start(speed, *wheel_motors)
    end
  end

  # ゆっくり右に回る
  def turn_right_slow(speed=WHEEL_SLOW)
    operate do
      @brick.reverse_polarity(RIGHT_WHEEL_MOTOR)
      @brick.start(speed, *wheel_motors)
    end
  end

  # 左に回る
  def turn_left(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(LEFT_WHEEL_MOTOR)
      @brick.start(speed, *wheel_motors)
    end
  end

  # ゆっくり左に回る
  def turn_left_slow(speed=WHEEL_SLOW)
    operate do
      @brick.reverse_polarity(LEFT_WHEEL_MOTOR)
      @brick.start(speed, *wheel_motors)
    end
  end

  # アームを上げる
  def raise_arm(speed=ARM_UP_SPEED)
    operate do
      @brick.reverse_polarity(*arm_motors)
      @brick.start(speed, *arm_motors)
    end
  end

  # アームをゆっくり上げる
  def raise_arm_slow(speed=ARM_UP_SLOW)
    operate do
      @brick.reverse_polarity(*arm_motors)
      @brick.start(speed, *arm_motors)
    end
  end

  # アームを下げる
  def down_arm(speed=ARM_DOWN_SPEED)
    operate do
      @brick.start(speed, *arm_motors)
    end
  end

  # 動きを止める
  def stop
    @brick.stop(true, *all_motors)
    @brick.run_forward(*all_motors)
    @busy = false
  end

   # 投げる
   def throw_ball(ARM_UP_SPEED)
     operate do
       @brick.reverse_polarity(*arm_motors)
       @brick.step_velocity(speed,130,10,*arm_motors)
       @brick.motor_ready(*arm_motors)
     end
   end

  # ある動作中は別の動作を受け付けないようにする
  def operate
    unless @busy
      @busy = true
      yield(@brick)
    end
  end

  # センサー情報の更新
  def update
    @distance = @brick.get_sensor(DISTANCE_SENSOR, 0)
  end

  # センサー情報の更新とキー操作受付
  def run
    #update
    run_forward if Input.keyDown?(K_UP)
    run_backward if Input.keyDown?(K_DOWN)
    turn_left if Input.keyDown?(K_LEFT)
    turn_right if Input.keyDown?(K_RIGHT)
    raise_arm if Input.keyDown?(K_W)
    down_arm if Input.keyDown?(K_S)
    run_forward_slow if Input.keyDown?(K_I)
    run_backward_slow if Input.keyDown?(K_M)
    turn_left_slow if Input.keyDown?(K_K)
    turn_right_slow if Input.keyDown?(K_J)
   throw_ball if Input.keyDown?(K_A)
    stop if [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_W, K_S,K_A].all?{|key| !Input.keyDown?(key) }
  end

  # 終了処理
  def close
    stop
    @brick.clear_all
    @brick.disconnect
  end

  # "~_MOTOR"という名前の定数全ての値を要素とする配列を返す
  def all_motors
    @all_motors ||= self.class.constants.grep(/_MOTOR\z/).map{|c| self.class.const_get(c) }
  end

  def wheel_motors
    [LEFT_WHEEL_MOTOR, RIGHT_WHEEL_MOTOR]
  end

  def arm_motors
    [LEFT_ARM_MOTOR, RIGHT_ARM_MOTOR]
  end
end

begin
  puts "starting..."
  font = Font.new(32)
  offence = Offence.new
  puts "connected..."

  Window.loop do
    break if Input.keyDown?(K_SPACE)
    offence.run
    Window.draw_font(100, 200, "#{offence.distance.to_i}cm", font)
  end
rescue
  p $!
  $!.backtrace.each{|trace| puts trace}
# 終了処理は必ず実行する
ensure
  puts "closing..."
  offence.close
  puts "finished..."
end
