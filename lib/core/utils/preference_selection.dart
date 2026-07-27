sealed class PreferenceSelection<T> {
  const PreferenceSelection();
}

final class PreferenceSelected<T> extends PreferenceSelection<T> {
  final T value;

  const PreferenceSelected(this.value);
}

final class PreferenceCleared<T> extends PreferenceSelection<T> {
  const PreferenceCleared();
}
