extends Node

## AudioManager — Autoload 单例
##
## 负责播放全局音效。所有音效共用同一个播放器：后播的音效会打断先播的，
## 保证提交结果音效不会被未播完的倒计时提示音盖住。

const SOUND_CORRECT := preload("res://assets/sounds/correct.wav")
const SOUND_FAIL := preload("res://assets/sounds/fail.wav")
const SOUND_TIME_UP := preload("res://assets/sounds/time_up.wav")

var _player: AudioStreamPlayer = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


## 提交通过（过关及以上）音效
func play_correct() -> void:
	_play(SOUND_CORRECT)


## 提交未通过（继续练习）音效
func play_fail() -> void:
	_play(SOUND_FAIL)


## 计时模式最后两秒提示音
func play_time_up() -> void:
	_play(SOUND_TIME_UP)


func _play(stream: AudioStream) -> void:
	if _player == null:
		return
	_player.stream = stream
	_player.play()
