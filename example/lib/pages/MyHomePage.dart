import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  @override
  State createState() => new MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    _controller = new AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    _animation = new IntTween(begin: 0, end: 34).animate(_controller);
  }

   @override
  void didChangeDependencies() {
    final List<String> frameNames = List.generate(35, (index) => 'frame_${index.toString().padLeft(2, '0')}_delay-0.1s.gif');

    for (final frameName in frameNames) {
      precacheImage(AssetImage('assets/meds/$frameName'), context);
    }
    super.didChangeDependencies();
  }


  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new AnimatedBuilder(
            animation: _animation,
            builder: (BuildContext context, Widget? child) {
              String frame = _animation.value.toString().padLeft(2, '0');
              return new Image.asset(
                'assets/meds/frame_${frame}_delay-0.1s.gif',
                gaplessPlayback: true,
              );
            },
          ),
           Expanded(
            child:
          new AnimatedBuilder(
            animation: _animation,
            builder: (BuildContext context, Widget? child) {
              String frame = _animation.value.toString().padLeft(2, '0');
          return new Container(
  constraints: BoxConstraints.expand(),
  decoration: BoxDecoration(
    image: DecorationImage(
        image: AssetImage('assets/meds/frame_${frame}_delay-0.1s.gif'), 
        fit: BoxFit.cover),
  ),);
            },
          ),
           ),
          new Text('Image: Guillaume Kurkdjian', style: new TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}