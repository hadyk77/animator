part of 'animator.dart';

///{@template animatorState}
///The state of [Animator] widget.
///
///From the parameter defined in the [Animator] widget, it instantiates
///the animation.
///
///{@endtemplate}
abstract class AnimatorState<T> {
  ///{@macro animatorState}
  factory AnimatorState(Animator<T> animator, void Function() rebuildStates) {
    return AnimatorStateImp<T>(animator, rebuildStates);
  }

  void resetAnimation({
    Tween<T?>? tween,
    Map<String, Tween>? tweenMap,
    Duration? duration,
    Curve? curve,
    int? repeats,
    int? cycles,
  });

  void triggerAnimation({bool restart = false});

  ///The [AnimationController] for an animation.
  ///
  ///It lets you perform tasks such as:
  ///* paly, reverse, stop animation
  ///* Set the animation to a specific.
  AnimationController get controller;

  ///The [Animation] object
  Animation<T> get animation;

  ///get the animation of provided name
  ///
  ///It will throw if [Animator.tweenMap] is null
  Animation<R> getAnimation<R>(String name);

  ///The value of the [animation]
  T get value;

  ///The value map of the [Animator.tweenMap];
  R getValue<R>(String name);
}

///Implementation of [AnimatorState]
class AnimatorStateImp<T> implements AnimatorState<T> {
  void Function() rebuildStates;

  ///Implementation of [AnimatorState]
  AnimatorStateImp(Animator<T>? animator, this.rebuildStates) {
    if (animator != null) {
      this.animator = animator;
    }
  }

  ///The animator widget the AnimatorState is associated with
  late Animator<T> animator;
  //
  AnimationController? _controller;
  @override
  AnimationController get controller => _controller!;
  //
  Animation<T>? _animation;
  @override
  Animation<T> get animation =>
      _animation ??= controller.drive(_curveTween as Animatable<T>);

  // _animation!;
  @override
  T get value {
    return _curveTween.evaluate(controller)!;
  }

  late Animatable<dynamic> _curveTween;

  late Duration _duration = animator.duration!;
  set duration(Duration duration) {
    if (_duration != duration) {
      _duration = duration;
      _controller!.duration = _duration;
    }
  }

  late Curve _curve = animator.curve!;
  set curve(Curve curve) {
    _curve = curve;
  }

  //
  late Tween<T?>? _tween = animator.tween;
  set tween(Tween<T?>? tween) {
    tween ??= (Tween<double>(begin: 0, end: 1) as Tween<T>);
    _curveTween = tween.chain(CurveTween(curve: _curve));
    _tween = tween;
  }

  Map<String, Tween<dynamic>> _tweenMap = {};
  set tweenMap(Map<String, Tween> newTweens) {
    _tweenMap = newTweens;
    _animationMap.clear();
    _valuesMap.clear();
    _tweenMap.forEach((key, tween) {
      _curvedTweenMap[key] = tween.chain(CurveTween(curve: _curve));
    });
  }

  Map<String, Animatable<dynamic>> _curvedTweenMap = {};
  @override
  final Map<String, Animation> _animationMap = {};

  @override
  Animation<R> getAnimation<R>(String name) {
    assert(_tweenMap.isNotEmpty);
    var anim = _animationMap[name];
    if (anim != null) {
      return anim as Animation<R>;
    }
    anim = controller.drive(_curvedTweenMap[name]!);
    _animationMap[name] = anim;
    return anim as Animation<R>;
  }

  Map<String, dynamic> _valuesMap = {};
  @override
  R getValue<R>(String name) {
    assert(_tweenMap.isNotEmpty);
    assert(_curvedTweenMap[name] != null);
    final val = _curvedTweenMap[name]!.evaluate(controller);
    _valuesMap[name] = val;
    return val;
  }

  //
  bool get _triggerOnInit => animator.triggerOnInit != null
      ? animator.triggerOnInit!
      : animator.animatorKey != null
          ? false
          : true;
  //
  late int _repeatCount;
  late bool _isCycle;
  bool _skipDismissStatus = false;
  //

  ///initialize animation
  void initAnimation(TickerProvider ticker) {
    _controller ??= AnimationController(
      duration: _duration,
      vsync: ticker,
    );

    resetAnimation(
      tween: animator.tween,
      tweenMap: animator.tweenMap,
      repeats: animator.repeats,
      cycles: animator.cycles,
    );

    _addAnimationListeners();

    if (animator.statusListener != null) {
      controller.addStatusListener(
        (status) => animator.statusListener!(status, this),
      );
    }

    if (animator.animatorKey != null) {
      controller.addListener((animator.animatorKey as AnimatorKeyImp)._rebuild);
    }

    if (_triggerOnInit == true) {
      triggerAnimation();
    }
  }

  void resetAnimation({
    Tween<T?>? tween,
    Map<String, Tween>? tweenMap,
    Duration? duration,
    Curve? curve,
    int? repeats,
    int? cycles,
  }) {
    this.duration = duration ?? _duration;
    this.curve = curve ?? _curve;
    this.tween = tween ?? _tween;
    this.tweenMap = tweenMap ?? _tweenMap;

    _animation = null;

    _isCycle = repeats == null && cycles != null;
    _setRepeatCount(animator.repeats, animator.cycles);
    _addAnimationStatusListener(_getStatusListenerCallBack);
  }

  void _addAnimationListeners() {
    controller.addListener(rebuildStates);
    if (animator.customListener != null) {
      controller.addListener(() => animator.customListener!(this));
    }
  }

  void _setRepeatCount(int? repeats, int? cycles) {
    _repeatCount = repeats == null ? cycles ?? 1 : repeats;
  }

  ///
  void _addAnimationStatusListener(void Function(AnimationStatus status) fn) {
    _removeStatusListener(fn);
    _addStatusListener(fn);
  }

  void _addStatusListener(void Function(AnimationStatus) listener) {
    controller.addStatusListener(listener);
  }

  void _removeStatusListener(void Function(AnimationStatus)? listener) {
    if (listener == null) return;
    controller.removeStatusListener(listener);
  }

  ///Start the animation
  void triggerAnimation({bool restart = false}) {
    if (restart) {
      _skipDismissStatus = true;
      controller.value = 0;
      _skipDismissStatus = false;
    }
    if (controller.status == AnimationStatus.dismissed) {
      controller.forward();
    } else if (controller.status == AnimationStatus.completed) {
      if (!_isCycle) {
        controller
          ..value = 0
          ..forward();
      } else {
        controller.reverse();
      }
    }
  }

  late Function(AnimationStatus) _getStatusListenerCallBack = (status) {
    if (status == AnimationStatus.completed ||
        (status == AnimationStatus.dismissed &&
            _isCycle &&
            !_skipDismissStatus)) {
      if (_repeatCount == 1) {
        if (animator.endAnimationListener != null) {
          animator.endAnimationListener!(this);
        }
        _setRepeatCount(animator.repeats, animator.cycles);
        // if (animator.animatorKey == null &&
        //     animator.resetAnimationOnRebuild != true) {
        //   _controller?.dispose();
        // }//TODO what if remove me
      } else {
        if (status == AnimationStatus.completed) {
          if (_repeatCount > 1) _repeatCount--;
          if (_isCycle) {
            controller.reverse();
          } else {
            controller
              ..value = 0
              ..forward();
          }
        } else if (status == AnimationStatus.dismissed) {
          if (_repeatCount > 1) _repeatCount--;
          controller.forward();
        }
      }
    }
  };
}
