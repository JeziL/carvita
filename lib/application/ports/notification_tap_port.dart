abstract interface class NotificationTapPort {
  void enqueuePayload(String? payload);

  void navigatorReady();
}
