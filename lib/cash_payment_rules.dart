const validCashPaymentMethods = <String>{
  'tunai',
  'transfer',
  'lainnya',
};

bool cashPaymentProofIsRequired(String method) => method == 'transfer';

bool cashPaymentCanBeSubmitted({
  required String method,
  required String? proofPath,
}) {
  if (!validCashPaymentMethods.contains(method)) return false;
  if (proofPath != null && proofPath.trim().isEmpty) return false;
  return !cashPaymentProofIsRequired(method) || proofPath != null;
}
