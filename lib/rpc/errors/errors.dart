class BaseError extends Error {
  final String message;
  BaseError(this.message);
}
class MissingKeyError extends BaseError {
  MissingKeyError(super.message);
}
class SignatureError extends BaseError {
  SignatureError(super.message);
}
class WalletError extends BaseError {
  WalletError(super.message);
}