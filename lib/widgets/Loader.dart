import 'package:flutter/material.dart';
import 'package:gym_progression/screens/Dashboard.dart';

class AppLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => Dashboard()));

    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'You have pushed the button this many times:',
          ),
          Text(
            'Loading app',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
