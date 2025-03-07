import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../models/workout.dart';
import 'package:intl/intl.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class GymSessionScreen extends StatefulWidget {
  @override
  State<GymSessionScreen> createState() => _GymSessionScreenState();
}

class _GymSessionScreenState extends State<GymSessionScreen> {
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countUp);
  final _isHours = true;
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _stopWatchTimer.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            StreamBuilder<int> (stream: _stopWatchTimer.rawTime, initialData:_stopWatchTimer.rawTime.value, builder: (context, snapshot){
              final value = snapshot.data;
              final displaytime = StopWatchTimer.getDisplayTime(value!, hours: _isHours);
              return Text(displaytime, style: const TextStyle(fontSize:40.0, fontWeight:FontWeight.bold,));
            },),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                onPressed: (){
                  _stopWatchTimer.onStartTimer();
                },
                style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 10, 82, 13),
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold)),
                child:Text(
                  'Start Timer',
                  style: TextStyle(color: Colors.white)
                )
              ), ElevatedButton(
                onPressed: (){
                  _stopWatchTimer.onStopTimer();
                },
                style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 73, 9, 5),
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold)),
                child:Text(
                  'Stop Timer',
                  style: TextStyle(color: Colors.white)
                )
              ), 

              ],
            )
          ]





        )




      )
    );
  }
}
