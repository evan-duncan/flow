export class InvalidAmount extends Error {
  constructor(amountCents) {
    super(`Invoice amount must be a positive whole number of cents, got ${amountCents}`);
    this.name = "InvalidAmount";
  }
}

export class AlreadyPaid extends Error {
  constructor(id) {
    super(`Invoice ${id} is already paid`);
    this.name = "AlreadyPaid";
  }
}
