export function calculatePricing(
  nightlyRate: number,
  numNights: number,
  cleaningFee: number,
  serviceFeePct: number
) {
  const subtotal = nightlyRate * numNights;
  const serviceFee = Math.round(subtotal * serviceFeePct);
  const total = subtotal + cleaningFee + serviceFee;
  return { subtotal, cleaningFee, serviceFee, total, numNights };
}

export function centsToStr(c: number) {
  return (c / 100).toFixed(2);
}

export function centsToDollars(c: number) {
  return `$${(c / 100).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
}
