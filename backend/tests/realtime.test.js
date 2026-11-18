'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { io: ioClient } = require('socket.io-client');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');

function makeToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, getJwtSecret(), {
    expiresIn: '1h',
  });
}

function createRealtimeMockDb() {
  const users = [
    { id: 1, nama: 'Pembeli Satu', email: 'buyer1@example.com', banned_at: null },
    { id: 2, nama: 'Penjual Dua', email: 'seller2@example.com', banned_at: null },
    { id: 3, nama: 'Pengguna Bebas', email: 'user3@example.com', banned_at: null },
    { id: 4, nama: 'Banned Seller', email: 'banned@example.com', banned_at: new Date().toISOString() },
  ];

  const events = [
    {
      id: 1,
      nama: 'Festival Musik Senja',
      poster_url: 'https://example.com/poster.jpg',
    },
  ];

  const listings = [
    {
      id: 10,
      event_id: 1,
      seller_id: 2,
      harga: 300000,
      jumlah_total: 2,
      jumlah_terjual: 0,
      waktu_acara: new Date(Date.now() + 5 * 86400_000).toISOString(),
      deleted_at: null,
      hidden: false,
      izinkan_wa: true,
    },
  ];

  let nextConvId = 1;
  let nextMsgId = 1;

  const conversations = [];
  const messages = [];
  const blocks = [];

  function addConv(data) {
    const conv = {
      id: nextConvId++,
      listing_id: data.listing_id,
      buyer_id: data.buyer_id,
      seller_id: data.seller_id,
      last_message_at: data.last_message_at || new Date().toISOString(),
      last_message_preview: data.last_message_preview || '',
      buyer_last_read_at: data.buyer_last_read_at || new Date().toISOString(),
      seller_last_read_at: data.seller_last_read_at || null,
      created_at: data.created_at || new Date().toISOString(),
    };
    conversations.push(conv);
    return conv;
  }

  function addMsg(data) {
    const msg = {
      id: nextMsgId++,
      conversation_id: data.conversation_id,
      sender_id: data.sender_id,
      isi: data.isi,
      created_at: data.created_at || new Date().toISOString(),
    };
    messages.push(msg);
    return msg;
  }

  function isBlockedBetween(u1, u2) {
    return blocks.some(
      (b) =>
        (b.blocker_id === u1 && b.blocked_id === u2) ||
        (b.blocker_id === u2 && b.blocked_id === u1)
    );
  }

  function getUnreadCount(conv, userId) {
    const isBuyer = conv.buyer_id === userId;
    const lastRead = isBuyer ? conv.buyer_last_read_at : conv.seller_last_read_at;
    const readTs = lastRead ? new Date(lastRead).getTime() : 0;

    return messages.filter(
      (m) =>
        m.conversation_id === conv.id &&
        m.sender_id !== userId &&
        new Date(m.created_at).getTime() > readTs
    ).length;
  }

  function hydrateConv(c, currentUserId) {
    const listing = listings.find((l) => l.id === c.listing_id) || {};
    const event = events.find((e) => e.id === listing.event_id) || {};
    const buyer = users.find((u) => u.id === c.buyer_id) || {};
    const seller = users.find((u) => u.id === c.seller_id) || {};

    return {
      ...c,
      listing_id: listing.id,
      listing_harga: listing.harga,
      listing_deleted_at: listing.deleted_at,
      listing_hidden: listing.hidden,
      listing_waktu_acara: listing.waktu_acara,
      listing_jumlah_total: listing.jumlah_total,
      listing_jumlah_terjual: listing.jumlah_terjual,
      listing_izinkan_wa: listing.izinkan_wa,
      event_nama: event.nama,
      event_poster_url: event.poster_url,
      buyer_nama: buyer.nama,
      buyer_banned_at: buyer.banned_at,
      seller_nama: seller.nama,
      seller_banned_at: seller.banned_at,
      belum_dibaca: getUnreadCount(c, currentUserId),
    };
  }

  return {
    users,
    events,
    listings,
    conversations,
    messages,
    blocks,
    addConv,
    addMsg,
    query: async (sql, params = []) => {
      const q = sql.trim();

      // Auth middleware / socket auth user lookup
      if (q.includes('FROM users') && q.includes('WHERE id = $1')) {
        const u = users.find((x) => x.id === params[0]);
        return { rows: u ? [u] : [] };
      }

      // Check block
      if (q.includes('FROM blocks') && q.includes('WHERE (blocker_id = $1 AND blocked_id = $2)')) {
        const found = isBlockedBetween(params[0], params[1]);
        return { rows: found ? [{ 1: 1 }] : [] };
      }

      // Check listing for conversation start
      if (q.includes('FROM listings l') && q.includes('JOIN users u ON u.id = l.seller_id') && q.includes('WHERE l.id = $1')) {
        const l = listings.find((x) => x.id === params[0]);
        if (!l) return { rows: [] };
        const u = users.find((x) => x.id === l.seller_id);
        return {
          rows: [
            {
              id: l.id,
              seller_id: l.seller_id,
              deleted_at: l.deleted_at,
              hidden: l.hidden,
              waktu_acara: l.waktu_acara,
              jumlah_total: l.jumlah_total,
              jumlah_terjual: l.jumlah_terjual,
              seller_banned_at: u ? u.banned_at : null,
            },
          ],
        };
      }

      // Check existing conversation: SELECT id FROM conversations WHERE listing_id = $1 AND buyer_id = $2
      if (q.includes('FROM conversations') && q.includes('WHERE listing_id = $1 AND buyer_id = $2')) {
        const c = conversations.find(
          (x) => x.listing_id === params[0] && x.buyer_id === params[1]
        );
        return { rows: c ? [{ id: c.id }] : [] };
      }

      // Detail conversation fetch
      if (q.includes('FROM conversations c') && q.includes('JOIN listings l ON l.id = c.listing_id') && q.includes('WHERE c.id = $1')) {
        const c = conversations.find((x) => x.id === params[0]);
        if (!c) return { rows: [] };
        return { rows: [hydrateConv(c, params[1])] };
      }

      // Participant lookup: SELECT buyer_id, seller_id FROM conversations WHERE id = $1
      if (q.includes('SELECT buyer_id, seller_id FROM conversations WHERE id = $1')) {
        const c = conversations.find((x) => x.id === params[0]);
        return { rows: c ? [{ buyer_id: c.buyer_id, seller_id: c.seller_id }] : [] };
      }

      // Insert conversation
      if (q.includes('INSERT INTO conversations')) {
        const conv = addConv({
          listing_id: params[0],
          buyer_id: params[1],
          seller_id: params[2],
          last_message_preview: params[3],
          last_message_at: new Date().toISOString(),
          buyer_last_read_at: new Date().toISOString(),
        });
        return { rows: [{ id: conv.id }] };
      }

      // Insert message
      if (q.includes('INSERT INTO messages')) {
        const msg = addMsg({
          conversation_id: params[0],
          sender_id: params[1],
          isi: params[2],
          created_at: new Date().toISOString(),
        });
        return { rows: [msg] };
      }

      // Update conversations last_message
      if (q.includes('UPDATE conversations') && q.includes('SET last_message_at = now()')) {
        const convId = params[0];
        const preview = params[1];
        const c = conversations.find((x) => x.id === convId);
        if (c) {
          c.last_message_at = new Date().toISOString();
          c.last_message_preview = preview;
          if (q.includes('buyer_last_read_at = now()')) {
            c.buyer_last_read_at = new Date().toISOString();
          } else if (q.includes('seller_last_read_at = now()')) {
            c.seller_last_read_at = new Date().toISOString();
          }
        }
        return { rowCount: 1 };
      }

      // Update read status
      if (q.includes('UPDATE conversations SET buyer_last_read_at = now() WHERE id = $1')) {
        const c = conversations.find((x) => x.id === params[0]);
        if (c) c.buyer_last_read_at = new Date().toISOString();
        return { rowCount: 1 };
      }
      if (q.includes('UPDATE conversations SET seller_last_read_at = now() WHERE id = $1')) {
        const c = conversations.find((x) => x.id === params[0]);
        if (c) c.seller_last_read_at = new Date().toISOString();
        return { rowCount: 1 };
      }

      // Count unread in conversation for counterparty
      if (q.includes('SELECT count(*)::int AS count FROM messages m') && q.includes('JOIN conversations c ON c.id = m.conversation_id')) {
        const convId = params[0];
        const lawanId = params[1];
        const c = conversations.find((x) => x.id === convId);
        if (!c) return { rows: [{ count: 0 }] };
        const unread = getUnreadCount(c, lawanId);
        return { rows: [{ count: unread }] };
      }

      // countUnreadChats
      if (q.includes('SELECT count(*)::int AS chats') && q.includes('FROM conversations c')) {
        const currentUserId = params[0];
        let count = 0;
        for (const c of conversations) {
          if (c.buyer_id !== currentUserId && c.seller_id !== currentUserId) {
            continue;
          }
          const unread = getUnreadCount(c, currentUserId);
          if (unread > 0) {
            count++;
          }
        }
        return { rows: [{ chats: count }] };
      }

      return { rows: [] };
    },
  };
}

describe('T6.2: Backend Socket.IO Realtime Service', () => {
  let db;
  let app;
  let server;
  let port;
  let buyerToken;
  let sellerToken;
  let bannedToken;
  const activeSockets = [];

  function createClientSocket(token) {
    const socket = ioClient(`http://localhost:${port}`, {
      auth: { token },
      transports: ['websocket'],
      forceNew: true,
      reconnection: false,
    });
    activeSockets.push(socket);
    return socket;
  }

  beforeAll((done) => {
    db = createRealtimeMockDb();
    app = createApp({ db, useRateLimit: false });
    server = app.server;
    server.listen(0, () => {
      port = server.address().port;
      done();
    });

    buyerToken = makeToken(db.users[0]);
    sellerToken = makeToken(db.users[1]);
    bannedToken = makeToken(db.users[3]);
  });

  afterAll((done) => {
    for (const s of activeSockets) {
      if (s.connected) s.disconnect();
    }
    if (app.io) {
      app.io.close();
    }
    server.close(done);
  });

  describe('Autentikasi Koneksi Socket.IO (API.md Bagian 10)', () => {
    it('gagal menyambung jika tidak ada token autentikasi (connect_error UNAUTHORIZED)', (done) => {
      const socket = ioClient(`http://localhost:${port}`, {
        auth: {},
        transports: ['websocket'],
        forceNew: true,
        reconnection: false,
      });
      activeSockets.push(socket);

      socket.on('connect_error', (err) => {
        expect(err.message).toMatch(/Token autentikasi diperlukan/i);
        expect(err.data?.code).toBe('UNAUTHORIZED');
        done();
      });
    });

    it('gagal menyambung jika token tidak valid (connect_error UNAUTHORIZED)', (done) => {
      const socket = ioClient(`http://localhost:${port}`, {
        auth: { token: 'invalid.jwt.token' },
        transports: ['websocket'],
        forceNew: true,
        reconnection: false,
      });
      activeSockets.push(socket);

      socket.on('connect_error', (err) => {
        expect(err.message).toMatch(/Token tidak valid/i);
        expect(err.data?.code).toBe('UNAUTHORIZED');
        done();
      });
    });

    it('gagal menyambung jika akun pengguna dibekukan (connect_error FORBIDDEN)', (done) => {
      const socket = createClientSocket(bannedToken);

      socket.on('connect_error', (err) => {
        expect(err.message).toMatch(/Akun telah dibekukan/i);
        expect(err.data?.code).toBe('FORBIDDEN');
        done();
      });
    });

    it('berhasil menyambung dan otomatis masuk room user:{id} jika token valid', (done) => {
      const socket = createClientSocket(buyerToken);

      socket.on('connect', () => {
        expect(socket.connected).toBe(true);

        // Verifikasi bahwa server memasukkan socket ke room user:1
        const room = app.io.sockets.adapter.rooms.get('user:1');
        expect(room).toBeDefined();
        expect(room.has(socket.id)).toBe(true);
        done();
      });
    });
  });

  describe('Penyiaran Realtime: message:new & unread:update', () => {
    let buyerSocket;
    let sellerSocket;

    beforeEach((done) => {
      let connectedCount = 0;
      buyerSocket = createClientSocket(buyerToken);
      sellerSocket = createClientSocket(sellerToken);

      function checkConnected() {
        connectedCount++;
        if (connectedCount === 2) done();
      }

      buyerSocket.on('connect', checkConnected);
      sellerSocket.on('connect', checkConnected);
    });

    afterEach(() => {
      if (buyerSocket) {
        buyerSocket.removeAllListeners();
        buyerSocket.disconnect();
      }
      if (sellerSocket) {
        sellerSocket.removeAllListeners();
        sellerSocket.disconnect();
      }
    });

    it('menyiarkan message:new dan unread:update ke penjual saat pembeli memulai chat (POST /listings/:id/conversations)', (done) => {
      let receivedMessageNew = false;
      let receivedUnreadUpdate = false;

      sellerSocket.on('message:new', (payload) => {
        expect(payload.message.isi).toBe('Halo penjual, tiket ready?');
        expect(payload.message.sender_id).toBe(1);
        expect(payload.conversation.belum_dibaca).toBe(1);
        receivedMessageNew = true;
        if (receivedMessageNew && receivedUnreadUpdate) done();
      });

      sellerSocket.on('unread:update', (payload) => {
        expect(payload.chats).toBe(1);
        receivedUnreadUpdate = true;
        if (receivedMessageNew && receivedUnreadUpdate) done();
      });

      // Pengirim (buyer) tidak boleh menerima message:new
      buyerSocket.on('message:new', () => {
        done(new Error('Pengirim seharusnya tidak menerima event message:new'));
      });

      // REST request
      request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo penjual, tiket ready?' })
        .expect(201)
        .end((err) => {
          if (err) return done(err);
        });
    });

    it('menyiarkan message:new ke pembeli saat penjual membalas pesan (POST /conversations/:id/messages)', (done) => {
      // Pembeli mendengar pesan masuk
      buyerSocket.on('message:new', (payload) => {
        expect(payload.message.isi).toBe('Iya masih ready kak!');
        expect(payload.message.sender_id).toBe(2);
        expect(payload.conversation.id).toBe(1);
        done();
      });

      // Penjual mengirim balasan via REST
      request(app)
        .post('/api/v1/conversations/1/messages')
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ isi: 'Iya masih ready kak!' })
        .expect(201)
        .end((err) => {
          if (err) return done(err);
        });
    });

    it('menyiarkan unread:update ke pembaca saat percakapan ditandai telah dibaca (POST /conversations/:id/read)', (done) => {
      sellerSocket.on('unread:update', (payload) => {
        expect(payload.chats).toBe(0);
        done();
      });

      // Penjual membaca percakapan via REST
      request(app)
        .post('/api/v1/conversations/1/read')
        .set('Authorization', `Bearer ${sellerToken}`)
        .expect(200)
        .end((err) => {
          if (err) return done(err);
        });
    });
  });
});
