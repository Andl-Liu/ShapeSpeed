extends Node

## GameManager — Autoload 单例
##
## 管理练习生命周期：创建 → 进行中 → 提交 → 展示结果 → 下一题。


# ── 状态枚举 ──

enum State {
	IDLE,
	PLAYING,
	SHOWING_RESULT,
}


# ── 信号 ──

## 新练习已生成（渲染层连接此信号获取 exercise 实例）
signal exercise_started(exercise: BaseExercise)

## 当前练习已提交，结果就绪
signal result_ready(result: Dictionary)

## 状态变化
signal state_changed(new_state: State)


# ── 内部状态 ──

var _current_exercise: BaseExercise = null
var _state: State = State.IDLE
var _round: int = 0
var _correct_count: int = 0
var _streak: int = 0

# 当前会话配置（默认值，可从外部修改）
var session_type: String = "angle_fixed_center"
var session_difficulty: int = 0
var session_options: Dictionary = {}


# ── 公开方法 ──

## 开始一轮新练习
func start_new_exercise() -> void:
	# 清理旧练习
	if _current_exercise:
		_current_exercise.cleanup()
		_current_exercise.queue_free()
		_current_exercise = null

	_current_exercise = ExerciseFactory.create_exercise(session_type, session_difficulty, session_options)
	_current_exercise.exercise_completed.connect(_on_exercise_completed)

	_round += 1
	_set_state(State.PLAYING)
	exercise_started.emit(_current_exercise)


## 用户点击「提交」
func submit_current_exercise() -> void:
	if _state != State.PLAYING or not _current_exercise:
		return

	var result: Dictionary = _current_exercise.validate()

	# 用练习自行判定的 Rating 决定是否「正确」——PASS 及以上即算过关
	var rating: int = result.get("rating", BaseExercise.Rating.PRACTICE)
	var is_correct: bool = (rating == BaseExercise.Rating.FLAWLESS or
							rating == BaseExercise.Rating.PERFECT or
							rating == BaseExercise.Rating.PASS)
	if is_correct:
		_correct_count += 1
		_streak += 1
	else:
		_streak = 0

	result["round"] = _round
	result["correct_count"] = _correct_count
	result["streak"] = _streak

	_set_state(State.SHOWING_RESULT)
	result_ready.emit(result)


## 进入下一题
func next_exercise() -> void:
	if _state != State.SHOWING_RESULT:
		return
	start_new_exercise()


## 重置整个会话
func reset_session() -> void:
	if _current_exercise:
		_current_exercise.cleanup()
		_current_exercise.queue_free()
		_current_exercise = null
	_round = 0
	_correct_count = 0
	_streak = 0
	_set_state(State.IDLE)


# ── 属性访问 ──

func get_current_exercise() -> BaseExercise:
	return _current_exercise


func get_state() -> State:
	return _state


func get_round() -> int:
	return _round


func get_correct_count() -> int:
	return _correct_count


func get_streak() -> int:
	return _streak


# ── 内部 ──

func _on_exercise_completed(_result: Dictionary) -> void:
	pass


func _set_state(new_state: State) -> void:
	_state = new_state
	state_changed.emit(_state)
