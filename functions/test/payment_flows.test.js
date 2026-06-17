const assert = require('assert');
const sinon = require('sinon');

const { _test } = require('../index');

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const FieldValue = {
  serverTimestamp: () => ({ __op: 'serverTimestamp' }),
  increment: (amount) => ({ __op: 'increment', amount }),
  arrayUnion: (...items) => ({ __op: 'arrayUnion', items }),
  delete: () => ({ __op: 'delete' }),
};

function resolveValue(previous, value) {
  if (!value || typeof value !== 'object' || !value.__op) return value;
  if (value.__op === 'serverTimestamp') return 'TEST_SERVER_TIMESTAMP';
  if (value.__op === 'increment') return Number(previous || 0) + Number(value.amount || 0);
  if (value.__op === 'arrayUnion') {
    const current = Array.isArray(previous) ? [...previous] : [];
    for (const item of value.items) {
      if (!current.includes(item)) current.push(item);
    }
    return current;
  }
  return value;
}

function applyData(current, data, merge) {
  const base = merge ? { ...(current || {}) } : {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value && typeof value === 'object' && value.__op === 'delete') {
      delete base[key];
    } else {
      base[key] = resolveValue(base[key], value);
    }
  }
  return base;
}

class FakeDocSnapshot {
  constructor(ref, data) {
    this.ref = ref;
    this.id = ref.id;
    this.exists = data !== undefined;
    this._data = data === undefined ? undefined : clone(data);
  }

  data() {
    return this._data === undefined ? undefined : clone(this._data);
  }
}

class FakeDocRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split('/').pop();
  }

  collection(name) {
    return new FakeCollectionRef(this.db, `${this.path}/${name}`);
  }

  async get() {
    return new FakeDocSnapshot(this, this.db._get(this.path));
  }

  async set(data, options = {}) {
    this.db._set(this.path, data, !!options.merge);
  }

  async update(data) {
    this.db._set(this.path, data, true);
  }
}

class FakeCollectionRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  doc(id) {
    return new FakeDocRef(this.db, `${this.path}/${id || this.db.nextId()}`);
  }

  where(field, op, value) {
    return new FakeQuery(this.db, this.path, [{ field, op, value }]);
  }

  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
}

class FakeQuery {
  constructor(db, path, filters, max = null) {
    this.db = db;
    this.path = path;
    this.filters = filters;
    this.max = max;
  }

  where(field, op, value) {
    return new FakeQuery(this.db, this.path, [...this.filters, { field, op, value }], this.max);
  }

  limit(max) {
    return new FakeQuery(this.db, this.path, this.filters, max);
  }

  async get() {
    let docs = this.db._docsInCollection(this.path)
      .filter(({ data }) => this.filters.every(({ field, op, value }) => {
        if (op !== '==') throw new Error(`Unsupported fake query op: ${op}`);
        return data[field] === value;
      }))
      .map(({ ref, data }) => new FakeDocSnapshot(ref, data));

    if (this.max !== null) docs = docs.slice(0, this.max);
    return { empty: docs.length === 0, docs };
  }
}

class FakeTransaction {
  constructor(db) {
    this.db = db;
  }

  async get(ref) {
    return ref.get();
  }

  set(ref, data, options = {}) {
    this.db._set(ref.path, data, !!options.merge);
  }

  update(ref, data) {
    this.db._set(ref.path, data, true);
  }
}

class FakeDb {
  constructor(seed = {}) {
    this.data = new Map();
    this.counter = 0;
    for (const [path, value] of Object.entries(seed)) {
      this.data.set(path, clone(value));
    }
  }

  nextId() {
    this.counter += 1;
    return `auto_${this.counter}`;
  }

  collection(name) {
    return new FakeCollectionRef(this, name);
  }

  async runTransaction(callback) {
    return callback(new FakeTransaction(this));
  }

  read(path) {
    const value = this._get(path);
    return value === undefined ? undefined : clone(value);
  }

  _get(path) {
    const value = this.data.get(path);
    return value === undefined ? undefined : clone(value);
  }

  _set(path, data, merge) {
    const current = this.data.get(path);
    this.data.set(path, applyData(current, data, merge));
  }

  _docsInCollection(path) {
    const prefix = `${path}/`;
    return [...this.data.entries()]
      .filter(([docPath]) => docPath.startsWith(prefix) && docPath.slice(prefix.length).split('/').length === 1)
      .map(([docPath, data]) => ({ ref: new FakeDocRef(this, docPath), data: clone(data) }));
  }
}

function deps(db, extra = {}) {
  return {
    db,
    FieldValue,
    enforceRateLimit: async () => ({ allowed: true }),
    isAdminUser: async () => false,
    ...extra,
  };
}

describe('payment and entitlement core flows', () => {
  afterEach(() => {
    sinon.restore();
  });

  it('maps subscription products to Pro and Enterprise tiers', () => {
    assert.strictEqual(_test.contractorSubscriptionTier('contractor_pro_monthly'), 'pro');
    assert.strictEqual(_test.contractorSubscriptionTier('contractor_enterprise_monthly'), 'enterprise');
  });

  it('grants contractor subscription entitlement once for checkout completion', async () => {
    const db = new FakeDb({
      'users/contractorA': { role: 'contractor' },
    });
    const session = {
      id: 'cs_sub_1',
      mode: 'subscription',
      amount_total: 2900,
      currency: 'usd',
      subscription: 'sub_1',
      customer: 'cus_1',
      metadata: { type: 'contractor_subscription', contractorId: 'contractorA' },
    };

    await _test.fulfillContractorSubscriptionCheckoutSession(session, deps(db));
    await _test.fulfillContractorSubscriptionCheckoutSession(session, deps(db));

    const user = db.read('users/contractorA');
    const payment = db.read('payments/cs_sub_1');
    assert.strictEqual(user.contractorPro, true);
    assert.strictEqual(user.pricingToolsPro, true);
    assert.strictEqual(user.stripeSubscriptionId, 'sub_1');
    assert.strictEqual(payment.type, 'contractor_subscription');
    assert.strictEqual(payment.status, 'success');
  });

  it('does not double-grant a duplicated Stripe lead pack checkout', async () => {
    const db = new FakeDb({ 'users/contractorA': { role: 'contractor' } });
    const session = {
      id: 'cs_lead_1',
      amount_total: 5000,
      currency: 'usd',
      payment_status: 'paid',
      status: 'complete',
      metadata: {
        type: 'lead_pack',
        contractorId: 'contractorA',
        packId: 'ne_1',
        creditType: 'non_exclusive',
      },
    };
    const getLeadPack = async () => ({ id: 'ne_1', leads: 3, amountCents: 5000, creditType: 'non_exclusive' });

    await _test.fulfillLeadPackFromCheckoutSession(session, deps(db, { getLeadPack }));
    await _test.fulfillLeadPackFromCheckoutSession(session, deps(db, { getLeadPack }));

    const user = db.read('users/contractorA');
    assert.strictEqual(user.leadCredits, 3);
    assert.strictEqual(user.credits, 3);
    assert.strictEqual(db.read('payments/cs_lead_1').leadsGranted, 3);
  });

  it('verifies lead pack purchase idempotently without live store credentials in tests', async () => {
    const db = new FakeDb({ 'users/contractorA': { role: 'contractor' } });
    const getLeadPack = async () => ({ id: 'ex_1', leads: 1, amountCents: 9900, creditType: 'exclusive' });

    const args = {
      uid: 'contractorA',
      productId: 'lead_ex_1',
      purchaseId: 'purchase_1',
      verificationData: 'receipt-token',
      source: 'google_play',
      deps: { ...deps(db, { getLeadPack }), skipReceiptVerification: true },
    };
    await _test.verifyLeadPackPurchaseCore(args);
    await _test.verifyLeadPackPurchaseCore(args);

    assert.strictEqual(db.read('users/contractorA').exclusiveLeadCredits, 1);
    assert.strictEqual(db.read('payments/iap_google_play_purchase_1').status, 'success');
  });

  it('marks escrow funded and updates the related job once', async () => {
    const db = new FakeDb({
      'escrow_bookings/escrowA': { status: 'created', aiPrice: 1200 },
      'job_requests/jobA': { status: 'accepted' },
    });
    const session = {
      id: 'cs_escrow_1',
      payment_intent: 'pi_1',
      metadata: { type: 'escrow_payment', escrowId: 'escrowA', customerId: 'customerA', jobId: 'jobA' },
    };

    await _test.fulfillEscrowPayment(session, deps(db));
    await _test.fulfillEscrowPayment(session, deps(db));

    assert.strictEqual(db.read('escrow_bookings/escrowA').status, 'funded');
    assert.strictEqual(db.read('escrow_bookings/escrowA').stripePaymentIntentId, 'pi_1');
    assert.strictEqual(db.read('job_requests/jobA').status, 'escrow_funded');
    assert.strictEqual(db.read('job_requests/jobA').escrowPrice, 1200);
  });

  it('refuses escrow release without both confirmations', async () => {
    const db = new FakeDb({
      'escrow_bookings/escrowA': {
        status: 'payoutPending',
        customerId: 'customerA',
        contractorId: 'contractorA',
        customerConfirmedAt: 'yes',
      },
    });

    await assert.rejects(
      () => _test.releaseEscrowFundsCore({ escrowId: 'escrowA', uid: 'customerA', deps: deps(db) }),
      (err) => err.code === 'failed-precondition'
    );
  });

  it('records manual payout status when contractor Stripe account is missing', async () => {
    const db = new FakeDb({
      'escrow_bookings/escrowA': {
        status: 'payoutPending',
        customerId: 'customerA',
        contractorId: 'contractorA',
        customerConfirmedAt: 'yes',
        contractorConfirmedAt: 'yes',
        contractorPayout: 95,
      },
      'contractors/contractorA': {},
    });

    const result = await _test.releaseEscrowFundsCore({ escrowId: 'escrowA', uid: 'customerA', deps: deps(db) });

    assert.strictEqual(result.pendingManual, true);
    assert.strictEqual(db.read('escrow_bookings/escrowA').payoutStatus, 'pending_manual');
  });

  it('releases escrow through Stripe once and treats duplicates as idempotent', async () => {
    const stripe = { transfers: { create: sinon.stub().resolves({ id: 'tr_1' }) } };
    const db = new FakeDb({
      'escrow_bookings/escrowA': {
        status: 'payoutPending',
        customerId: 'customerA',
        contractorId: 'contractorA',
        customerConfirmedAt: 'yes',
        contractorConfirmedAt: 'yes',
        contractorPayout: 95,
        jobId: 'jobA',
      },
      'contractors/contractorA': { stripeAccountId: 'acct_1' },
    });

    const first = await _test.releaseEscrowFundsCore({ escrowId: 'escrowA', uid: 'customerA', deps: deps(db, { stripe }) });
    const second = await _test.releaseEscrowFundsCore({ escrowId: 'escrowA', uid: 'customerA', deps: deps(db, { stripe }) });

    assert.strictEqual(first.transferId, 'tr_1');
    assert.strictEqual(second.alreadyTransferred, true);
    assert.strictEqual(stripe.transfers.create.callCount, 1);
    assert.strictEqual(db.read('escrow_bookings/escrowA').status, 'released');
  });

  it('refuses refunds after escrow release', async () => {
    const db = new FakeDb({
      'escrow_bookings/escrowA': {
        status: 'released',
        customerId: 'customerA',
        stripePaymentIntentId: 'pi_1',
      },
    });

    await assert.rejects(
      () => _test.refundEscrowCore({ escrowId: 'escrowA', uid: 'customerA', deps: deps(db) }),
      (err) => err.code === 'failed-precondition'
    );
  });

  it('records valid escrow refund fields and reopens the job', async () => {
    const stripe = { refunds: { create: sinon.stub().resolves({ id: 're_1', status: 'succeeded', amount: 120000 }) } };
    const db = new FakeDb({
      'escrow_bookings/escrowA': {
        status: 'funded',
        customerId: 'customerA',
        jobId: 'jobA',
        stripePaymentIntentId: 'pi_1',
      },
      'job_requests/jobA': {
        status: 'escrow_funded',
        escrowId: 'escrowA',
        escrowPrice: 1200,
        instantBook: true,
      },
    });

    const result = await _test.refundEscrowCore({ escrowId: 'escrowA', uid: 'customerA', deps: deps(db, { stripe }) });

    assert.strictEqual(result.refundId, 're_1');
    assert.strictEqual(db.read('escrow_bookings/escrowA').status, 'cancelled');
    assert.strictEqual(db.read('escrow_bookings/escrowA').refundAmountCents, 120000);
    assert.strictEqual(db.read('job_requests/jobA').status, 'open');
    assert.strictEqual(db.read('job_requests/jobA').escrowId, undefined);
  });

  it('resolves invoice checkout metadata back to contractor and invoice', () => {
    const result = _test.parseInvoiceCheckoutMetadata({
      id: 'cs_invoice_1',
      payment_intent: 'pi_invoice_1',
      metadata: {
        type: 'invoice_payment',
        contractorUid: 'contractorA',
        invoiceId: 'invoiceA',
      },
    });

    assert.deepStrictEqual(result, {
      contractorUid: 'contractorA',
      invoiceId: 'invoiceA',
      stripeSessionId: 'cs_invoice_1',
      paymentIntentId: 'pi_invoice_1',
    });
  });
});
