require 'dxruby'
require_relative 'ev3/ev3'

# TODO どうやってメソッドを組み合わせていくのか。window.loopで実行し続ける場合、それぞれのメソッドでwhileとかしない方がいいのか。実装方法とか変わってくる。offence.move_throw_positionをloopで実行した時、動いたけど、止まってからもピクピク動いてた。move_throw_positionが何回も実行されたんだろう。@stateを使ってうまくやるのか。

class Offence
  LEFT_WHEEL_MOTOR = "B"
  RIGHT_WHEEL_MOTOR = "C"
  LEFT_ARM_MOTOR = "A"
  RIGHT_ARM_MOTOR = "D"
  DISTANCE_SENSOR = "4"
  RIGHT_COLOR_SENSOR = "1"
  LEFT_COLOR_SENSOR = "2"
  PORT = "COM3"
  WHEEL_SPEED = 50
  ARM_SPEED = 10
  DEGREES_CLAW = 5000
  CLAW_POWER = 30

  attr_reader :distance #距離センサー
  attr_reader :right_color #右カラーセンサー
  attr_reader :left_color #左カラーセンサー
  attr_reader :direction # 自陣から見てロボが向いてる向き(rightかleft)
  attr_reader :state # 状態。1:

  def initialize
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
    @brick.connect
    @busy = false # 実行中には処理を受け付けないために
    @throwing = false # 「投げる」の動作状態を確認するために
  end

  # 投げる場所まで移動する
  def move_to_redline
    run_backward(20)
    # 赤線に到達したらstop
    while @right_color != 5 && @left_color != 5
      update
    end
    stop
  end

  # どちらのセンサーが赤線の上にいるかで分岐してトレース
  #TODO 赤線移動するのは指定秒数分。どうするか。move_to_redlineみたいにwhile回すか。
  def which_color_sensor
    if @right_color == 5
      @direction = "right"
      right_color_sensor_trace_redline
    elsif @left_color == 5
      @direction = "left"
      left_color_sensor_trace_redline
    end
  end

  # 3秒赤線を辿ることで向きを線と平行にする
  def right_color_sensor_trace_redline
    t1 = Time.now
    t2 = Time.now
    while (t2 - t1) < 3
      # 赤線の上にいるかどうかで分岐
      if @color == 5
        # Window.draw_font(100, 200, "on road", font)
        # 後退する
        run_backward
        sleep 0.2
        stop
      else
        # Window.draw_font(100, 200, "off road", font)
        # 少し前進する
        run_forward
        sleep 0.1
        stop
        # 少しだけ右に曲がる(左タイヤ前進、右タイヤ後退)
        turn_right
        sleep 0.1
        stop
        # 回転の向きを正方向に直す。回転の方向を記憶しているから。
        run_forward
      end
      t2 = Time.now
    end
  end

  def left_color_sensor_trace_redline
    t1 = Time.now
    t2 = Time.now
    while (t2 - t1) < 3
      # 赤線の上にいるかどうかで分岐
      if @color == 5
        # Window.draw_font(100, 200, "on road", font)
        # 後退する
        run_backward
        sleep 0.2
        stop
      else
        # Window.draw_font(100, 200, "off road", font)
        # 少し前進する
        run_forward
        sleep 0.1
        stop
        # 少しだけ左に曲がる(右タイヤ前進、左タイヤ後退)
        turn_left
        sleep 0.1
        stop
        # 回転の向きを正方向に直す。回転の方向を記憶しているから。
        run_forward
      end
      t2 = Time.now
    end
  end

  # 相手の方角へ投げるために回転する
  def rotate_throw_position
    if @direction == right
      turn_left
      sleep(2)
      stop
    elsif @direction == left
      turn_right
      sleep(2)
      stop
    end
  end

  # 投げる
  def throwing
    # raise_arm
    return if @throwing
    operate do
      @brick.reverse_polarity(*arm_motors)
      @brick.step_velocity(100,50,20,*arm_motors)
      @brick.motor_ready(*arm_motors)
      @throwing = true
    end
  end

   def return_throwing
    return unless @throwing
    operate do
      @brick.step_velocity(100,50,20,*arm_motors)
      @brick.motor_ready(*arm_motors)
      @throwing = false
    end
  end


  # 前進する。ここでモーターがどっち回転させたら前進するようになってるかといった部分を吸収する
  def run_forward(speed=WHEEL_SPEED)
    operate do
      @brick.start(speed, *wheel_motors)
    end
  end

  # バックする
  def run_backward(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(*wheel_motors)
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

  # 左に回る
  def turn_left(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(LEFT_WHEEL_MOTOR)
      @brick.start(speed, *wheel_motors)
    end
  end

  # アームを上げる
  def raise_arm(speed=ARM_SPEED)
    operate do
      @brick.reverse_polarity(*arm_motors)
      @brick.start(speed, *arm_motors)
    end
  end

  # アームを下げる
  def down_arm(speed=ARM_SPEED)
    operate do
      @brick.start(speed, *arm_motors)
    end
  end

  # 物を掴む
  # def grab
  #   return if @grabbing
  #   operate do
  #     @brick.reverse_polarity(*arm_motors)
  #     @brick.step_velocity(CLAW_POWER, DEGREES_CLAW, 0, *arm_motors)
  #     @brick.motor_ready(*arm_motors)
  #     @grabbing = true
  #   end
  # end

  # 物を離す
  # def release
  #   return unless @grabbing
  #   operate do
  #     @brick.step_velocity(CLAW_POWER, DEGREES_CLAW, 0, CLAW_MOTOR)
  #     @brick.motor_ready(CLAW_MOTOR)
  #     @grabbing = false
  #   end
  # end

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

  # センサー情報の更新
  def update
    @distance = @brick.get_sensor(DISTANCE_SENSOR, 0)
    @right_color = @brick.get_sensor(RIGHT_COLOR_SENSOR, 2)
    @left_color = @brick.get_sensor(LEFT_COLOR_SENSOR, 2)
  end

  def auto
    # move_to_redline
    # which_color_sensor
    # rotate_throw_position
    throwing
    sleep(3)
    return_throwing
  end

  # センサー情報の更新とキー操作受付
  def run
    update
    run_forward if Input.keyDown?(K_UP)
    run_backward if Input.keyDown?(K_DOWN)
    turn_left if Input.keyDown?(K_LEFT)
    turn_right if Input.keyDown?(K_RIGHT)
    raise_arm if Input.keyDown?(K_W)
    down_arm if Input.keyDown?(K_S)
    # grab if Input.keyDown?(K_A)
    # release if Input.keyDown?(K_D)
    stop if [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_W, K_S].all?{|key| !Input.keyDown?(key) }
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
    #offence.run
    offence.auto
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
