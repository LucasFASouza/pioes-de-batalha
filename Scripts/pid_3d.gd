extends RefCounted
class_name Pid3D

var _p: float
var _i: float
var _d: float


var _prev_error: float
var _error_integral: float


func _init(p: float = 0.0, i: float = 0.0, d: float = 0.0) -> void:
	_p = p
	_i = i
	_d = d


func update(error: Vector3, delta: float) -> Vector3:
	_error_integral += error * delta
	var error_derivative = (error - _prev_error) / delta
	_prev_error = error
	return _p * error + _i * _error_integral + _d * error_derivative
