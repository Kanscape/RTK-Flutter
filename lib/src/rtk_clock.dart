class RTKClock {
  const RTKClock();

  DateTime now() => DateTime.now().toUtc();
}

class FakeRTKClock extends RTKClock {
  FakeRTKClock(this.nowValue);

  DateTime nowValue;

  @override
  DateTime now() => nowValue.toUtc();
}
