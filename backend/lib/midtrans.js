import crypto from 'node:crypto';

class MidtransHelper {
  constructor() {
    this.serverKey = process.env.MIDTRANS_SERVER_KEY || '';
    this.clientKey = process.env.MIDTRANS_CLIENT_KEY || '';
    this.isProduction = process.env.MIDTRANS_IS_PRODUCTION === 'true';
    this.snapBaseUrl = this.isProduction
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
    this.apiBaseUrl = this.isProduction
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2';
  }

  isMockMode() {
    return !this.serverKey || this.serverKey.includes('PLACEHOLDER') || this.serverKey === 'mock';
  }

  verifySignature({ orderId, statusCode, grossAmount, signatureKey, serverKeyOverride }) {
    const key = serverKeyOverride || this.serverKey;
    const raw = `${orderId}${statusCode}${grossAmount}${key}`;
    const calculated = crypto.createHash('sha512').update(raw).digest('hex');
    return calculated.toLowerCase() === (signatureKey || '').toLowerCase();
  }

  async createSnapTransaction({ orderId, grossAmount, customerDetails, forceMock = false }) {
    if (this.isMockMode() || forceMock) {
      const mockToken = `mock-snap-${orderId}-${Date.now()}`;
      return {
        token: mockToken,
        redirect_url: `https://app.sandbox.midtrans.com/snap/v2/vtweb/${mockToken}`,
        is_mock: true
      };
    }

    const payload = {
      transaction_details: {
        order_id: orderId,
        gross_amount: Math.round(Number(grossAmount))
      },
      customer_details: customerDetails || {
        first_name: 'Pelanggan Resik.in'
      }
    };

    const authHeader = 'Basic ' + Buffer.from(this.serverKey + ':').toString('base64');
    const response = await fetch(this.snapBaseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': authHeader
      },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    if (!response.ok) {
      const errorMsg = data.error_messages ? data.error_messages.join(', ') : 'Gagal membuat sesi Midtrans Snap';
      throw new Error(errorMsg);
    }

    return {
      token: data.token,
      redirect_url: data.redirect_url,
      is_mock: false
    };
  }

  async checkTransactionStatus(orderId, { forceMockStatus = null } = {}) {
    if (forceMockStatus) {
      return forceMockStatus;
    }

    if (this.isMockMode()) {
      return {
        status_code: '200',
        transaction_status: 'settlement',
        payment_type: 'qris',
        transaction_id: `mock-txn-${orderId}`,
        settlement_time: new Date().toISOString()
      };
    }

    const authHeader = 'Basic ' + Buffer.from(this.serverKey + ':').toString('base64');
    const response = await fetch(`${this.apiBaseUrl}/${orderId}/status`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': authHeader
      }
    });

    if (!response.ok) {
      return null;
    }
    return await response.json();
  }
}

export const midtransHelper = new MidtransHelper();
