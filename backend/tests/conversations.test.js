'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/index');
const { getJwtSecret } = require('../src/middleware/auth');

function makeToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, getJwtSecret(), {
    expiresIn: '1h',
  });
}

function createConversationsMockDb() {
  const users = [
    { id: 1, nama: 'Pembeli Satu', email: 'buyer1@example.com', no_wa: '08111111111', banned_at: null },
    { id: 2, nama: 'Penjual Dua', email: 'seller2@example.com', no_wa: '081234567890', banned_at: null },
    { id: 3, nama: 'Pengguna Tiga', email: 'user3@example.com', no_wa: null, banned_at: null },
    { id: 4, nama: 'Banned Seller', email: 'banned@example.com', no_wa: '08199999999', banned_at: new Date().toISOString() },
  ];

  const events = [
    {
      id: 1,
      nama: 'Konser Sheila on 7',
      poster_url: 'https://example.com/poster.jpg',
    },
  ];

  const listings = [
    {
      id: 10,
      event_id: 1,
      seller_id: 2,
      harga: 350000,
      jumlah_total: 2,
      jumlah_terjual: 0,
      waktu_acara: new Date(Date.now() + 5 * 86400_000).toISOString(),
      deleted_at: null,
      hidden: false,
      izinkan_wa: false,
    },
    {
      id: 11,
      event_id: 1,
      seller_id: 2,
      harga: 350000,
      jumlah_total: 2,
      jumlah_terjual: 2, // terjual habis
      waktu_acara: new Date(Date.now() + 5 * 86400_000).toISOString(),
      deleted_at: null,
      hidden: false,
      izinkan_wa: true,
    },
    {
      id: 12,
      event_id: 1,
      seller_id: 4, // seller dibanned
      harga: 200000,
      jumlah_total: 1,
      jumlah_terjual: 0,
      waktu_acara: new Date(Date.now() + 5 * 86400_000).toISOString(),
      deleted_at: null,
      hidden: false,
      izinkan_wa: false,
    },
    {
      id: 13,
      event_id: 1,
      seller_id: 2,
      harga: 400000,
      jumlah_total: 1,
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

  function isBlockedBy(blockerId, blockedId) {
    return blocks.some(
      (b) => b.blocker_id === blockerId && b.blocked_id === blockedId
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
      seller_no_wa: seller.no_wa,
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

      // Auth middleware user lookup
      if (q.includes('FROM users') && q.includes('WHERE id = $1')) {
        const u = users.find((x) => x.id === params[0]);
        return { rows: u ? [u] : [] };
      }

      // Block check (checkBlockBetween)
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

      // Find buyer conversation for listing: SELECT c.id FROM conversations c WHERE c.listing_id = $1 AND c.buyer_id = $2
      if (q.includes('FROM conversations c') && q.includes('WHERE c.listing_id = $1 AND c.buyer_id = $2')) {
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

      // Total count conversations inbox
      if (q.includes('SELECT count(*)::int AS total') && q.includes('FROM conversations c')) {
        const currentUserId = params[0];
        const visible = conversations.filter((c) => {
          if (c.buyer_id !== currentUserId && c.seller_id !== currentUserId) {
            return false;
          }
          const lawanId = c.buyer_id === currentUserId ? c.seller_id : c.buyer_id;
          // BR-12: jika currentUserId memblokir lawan, sembunyikan
          return !isBlockedBy(currentUserId, lawanId);
        });
        return { rows: [{ total: visible.length }] };
      }

      // List conversations inbox
      if (q.includes('FROM conversations c') && q.includes('ORDER BY c.last_message_at DESC NULLS LAST')) {
        const currentUserId = params[0];
        const limit = params[1];
        const offset = params[2];

        const visible = conversations.filter((c) => {
          if (c.buyer_id !== currentUserId && c.seller_id !== currentUserId) {
            return false;
          }
          const lawanId = c.buyer_id === currentUserId ? c.seller_id : c.buyer_id;
          return !isBlockedBy(currentUserId, lawanId);
        });

        visible.sort((a, b) => {
          const ta = a.last_message_at ? new Date(a.last_message_at).getTime() : 0;
          const tb = b.last_message_at ? new Date(b.last_message_at).getTime() : 0;
          if (tb !== ta) return tb - ta;
          return b.id - a.id;
        });

        const paged = visible.slice(offset, offset + limit);
        return { rows: paged.map((c) => hydrateConv(c, currentUserId)) };
      }

      // Check conversation participant: SELECT buyer_id, seller_id FROM conversations WHERE id = $1
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

      // Update conversations read: UPDATE conversations SET buyer_last_read_at = now() WHERE id = $1
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

      // Fetch messages: SELECT id, conversation_id, sender_id, isi, created_at FROM messages WHERE conversation_id = $1
      if (q.includes('FROM messages') && q.includes('WHERE conversation_id = $1')) {
        const convId = params[0];
        let filtered = messages.filter((m) => m.conversation_id === convId);
        if (params.length === 3) {
          // with before param: params[1] is before, params[2] is limit+1
          const beforeId = params[1];
          const limit = params[2];
          filtered = filtered.filter((m) => m.id < beforeId);
          filtered.sort((a, b) => b.id - a.id);
          return { rows: filtered.slice(0, limit) };
        } else {
          // params[1] is limit+1
          const limit = params[1];
          filtered.sort((a, b) => b.id - a.id);
          return { rows: filtered.slice(0, limit) };
        }
      }

      // countUnreadChats
      if (q.includes('SELECT count(*)::int AS chats') && q.includes('FROM conversations c')) {
        const currentUserId = params[0];
        let count = 0;
        for (const c of conversations) {
          if (c.buyer_id !== currentUserId && c.seller_id !== currentUserId) {
            continue;
          }
          const lawanId = c.buyer_id === currentUserId ? c.seller_id : c.buyer_id;
          if (isBlockedBy(currentUserId, lawanId)) {
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

describe('T6.1: Backend Conversation and Message Endpoints', () => {
  let db;
  let app;
  let buyerToken;
  let sellerToken;
  let otherToken;

  beforeEach(() => {
    db = createConversationsMockDb();
    app = createApp({ db, useRateLimit: false });
    buyerToken = makeToken(db.users[0]); // User 1
    sellerToken = makeToken(db.users[1]); // User 2
    otherToken = makeToken(db.users[2]); // User 3
  });

  describe('POST /api/v1/listings/:id/conversations', () => {
    it('harus menolak request tanpa token auth (401)', async () => {
      const res = await request(app)
        .post('/api/v1/listings/10/conversations')
        .send({ isi: 'Halo' });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('harus menolak pesan kosong atau lebih dari 1000 karakter (422)', async () => {
      const resEmpty = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: '   ' });
      expect(resEmpty.status).toBe(422);

      const resLong = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'a'.repeat(1001) });
      expect(resLong.status).toBe(422);
    });

    it('harus 404 jika listing tidak ditemukan atau penjual dibanned', async () => {
      const resNotFound = await request(app)
        .post('/api/v1/listings/999/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo' });
      expect(resNotFound.status).toBe(404);

      const resBanned = await request(app)
        .post('/api/v1/listings/12/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo' });
      expect(resBanned.status).toBe(404);
    });

    it('harus menolak jika penjual mencoba chat ke listingnya sendiri (403 FORBIDDEN)', async () => {
      const res = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ isi: 'Mencoba chat diri sendiri' });
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('harus 403 BLOCKED jika penjual memblokir pembeli atau pembeli memblokir penjual (BR-12)', async () => {
      db.blocks.push({ blocker_id: 2, blocked_id: 1 }); // seller memblokir buyer
      const res = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo kak' });
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('BLOCKED');
    });

    it('harus 409 CONFLICT jika memulai percakapan baru pada listing yang sudah terjual habis', async () => {
      const res = await request(app)
        .post('/api/v1/listings/11/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Masih ada tiket?' });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('CONFLICT');
    });

    it('berhasil membuat percakapan dan pesan pertama secara atomik (201)', async () => {
      const res = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo, tiket masih ada?' });

      expect(res.status).toBe(201);
      expect(res.body.data.conversation).toBeDefined();
      expect(res.body.data.message).toBeDefined();

      const conv = res.body.data.conversation;
      expect(conv.id).toBe(1);
      expect(conv.listing.id).toBe(10);
      expect(conv.listing.judul).toBe('Konser Sheila on 7');
      expect(conv.lawan.id).toBe(2);
      expect(conv.lawan.nama).toBe('Penjual Dua');
      expect(conv.peran).toBe('pembeli');
      expect(conv.pesan_terakhir).toBe('Halo, tiket masih ada?');
      expect(conv.belum_dibaca).toBe(0);

      const msg = res.body.data.message;
      expect(msg.isi).toBe('Halo, tiket masih ada?');
      expect(msg.sender_id).toBe(1);
    });

    it('menambahkan pesan ke percakapan yang ada jika sudah pernah dibuat, bahkan jika tiket terjual', async () => {
      // Buat percakapan pertama
      await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Pesan 1' });

      // Ubah listing jadi terjual habis
      db.listings[0].jumlah_terjual = 2;

      // Kirim pesan lagi
      const res2 = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Pesan 2 lanjutan' });

      expect(res2.status).toBe(201);
      expect(res2.body.data.conversation.id).toBe(1);
      expect(res2.body.data.conversation.pesan_terakhir).toBe('Pesan 2 lanjutan');
      expect(res2.body.data.message.isi).toBe('Pesan 2 lanjutan');
      expect(db.messages.length).toBe(2);
    });
  });

  describe('GET /api/v1/listings/:id/conversation', () => {
    it('mengembalikan 404 jika belum ada percakapan antara pembeli dan listing', async () => {
      const res = await request(app)
        .get('/api/v1/listings/10/conversation')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('mengembalikan percakapan pembeli jika sudah ada (200)', async () => {
      await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo penjual' });

      const res = await request(app)
        .get('/api/v1/listings/10/conversation')
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(1);
      expect(res.body.data.peran).toBe('pembeli');
      expect(res.body.data.lawan.nama).toBe('Penjual Dua');
    });
  });

  describe('GET /api/v1/conversations (Kotak masuk chat)', () => {
    it('menampilkan daftar percakapan terurut pesan terakhir turun', async () => {
      // Buat chat 1
      await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Chat dari buyer 1' });

      // Penjual melihat kotak masuknya
      const resSeller = await request(app)
        .get('/api/v1/conversations')
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(resSeller.status).toBe(200);
      expect(resSeller.body.data.length).toBe(1);
      expect(resSeller.body.data[0].peran).toBe('penjual');
      expect(resSeller.body.data[0].lawan.nama).toBe('Pembeli Satu');
      expect(resSeller.body.data[0].belum_dibaca).toBe(1); // Belum dibaca oleh penjual!
      expect(resSeller.body.meta.total).toBe(1);
    });

    it('menyembunyikan percakapan jika pemblokirnya adalah pengguna yang meminta (BR-12)', async () => {
      await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Chat awal' });

      // Pembeli memblokir penjual
      db.blocks.push({ blocker_id: 1, blocked_id: 2 });

      // Kotak masuk pembeli tidak menampilkan chat dengan penjual
      const resBuyer = await request(app)
        .get('/api/v1/conversations')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(resBuyer.body.data.length).toBe(0);
      expect(resBuyer.body.meta.total).toBe(0);

      // Tapi di kotak masuk penjual, chat tetap terlihat (karena penjual bukan pemblokir)
      const resSeller = await request(app)
        .get('/api/v1/conversations')
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(resSeller.body.data.length).toBe(1);
    });
  });

  describe('GET /api/v1/conversations/:id', () => {
    it('mengembalikan 404 jika bukan peserta percakapan', async () => {
      await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo' });

      const resOther = await request(app)
        .get('/api/v1/conversations/1')
        .set('Authorization', `Bearer ${otherToken}`);
      expect(resOther.status).toBe(404);
    });

    it('mengembalikan detail percakapan untuk peserta yang sah (200)', async () => {
      await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo' });

      const res = await request(app)
        .get('/api/v1/conversations/1')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(1);
      expect(res.body.data.peran).toBe('pembeli');
    });
  });

  describe('GET /api/v1/conversations/:id/messages', () => {
    it('mengembalikan riwayat pesan berpaginasi before', async () => {
      const conv = db.addConv({
        listing_id: 10,
        buyer_id: 1,
        seller_id: 2,
      });

      for (let i = 1; i <= 35; i++) {
        db.addMsg({
          conversation_id: conv.id,
          sender_id: i % 2 === 0 ? 2 : 1,
          isi: `Pesan ${i}`,
        });
      }

      // Ambil 30 pesan pertama (default limit 30)
      const res = await request(app)
        .get(`/api/v1/conversations/${conv.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(30);
      expect(res.body.meta.ada_lebih_lama).toBe(true);
      expect(res.body.data[0].id).toBe(35); // Urut id turun

      // Ambil pesan sebelum ID 6
      const resOlder = await request(app)
        .get(`/api/v1/conversations/${conv.id}/messages?before=6`)
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(resOlder.status).toBe(200);
      expect(resOlder.body.data.length).toBe(5);
      expect(resOlder.body.meta.ada_lebih_lama).toBe(false);
    });
  });

  describe('POST /api/v1/conversations/:id/messages', () => {
    let convId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Pesan pembuka' });
      convId = res.body.data.conversation.id;
    });

    it('penjual dapat membalas pesan (201)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${convId}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ isi: 'Halo, masih ada kak!' });

      expect(res.status).toBe(201);
      expect(res.body.data.isi).toBe('Halo, masih ada kak!');
      expect(res.body.data.sender_id).toBe(2);
      expect(res.body.data.conversation_id).toBe(convId);

      const conv = db.conversations.find((c) => c.id === convId);
      expect(conv.last_message_preview).toBe('Halo, masih ada kak!');
    });

    it('menolak pengiriman jika ada pemblokiran di antara kedua pihak (403 BLOCKED)', async () => {
      db.blocks.push({ blocker_id: 1, blocked_id: 2 });

      const res = await request(app)
        .post(`/api/v1/conversations/${convId}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ isi: 'Balasan tidak terkirim' });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('BLOCKED');
    });

    it('menolak pengiriman pesan dari orang luar yang bukan peserta (404)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${convId}/messages`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ isi: 'Nimbrung' });

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/v1/conversations/:id/read & GET /api/v1/me/unread', () => {
    it('menandai pesan telah dibaca dan memperbarui unread count', async () => {
      // 1. Buyer kirim pesan ke seller
      const initRes = await request(app)
        .post('/api/v1/listings/10/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Halo Penjual' });
      const convId = initRes.body.data.conversation.id;

      // 2. Seller cek /api/v1/me/unread -> harus 1
      const unreadSeller1 = await request(app)
        .get('/api/v1/me/unread')
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(unreadSeller1.status).toBe(200);
      expect(unreadSeller1.body.data.chats).toBe(1);

      // 3. Buyer cek /api/v1/me/unread -> harus 0 (karena pesan dikirim sendiri)
      const unreadBuyer = await request(app)
        .get('/api/v1/me/unread')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(unreadBuyer.body.data.chats).toBe(0);

      // 4. Seller menandai telah dibaca: POST /conversations/:id/read
      const readRes = await request(app)
        .post(`/api/v1/conversations/${convId}/read`)
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(readRes.status).toBe(200);
      expect(readRes.body.data.belum_dibaca).toBe(0);
      expect(readRes.body.data.chats_belum_dibaca).toBe(0);

      // 5. Seller cek lagi /api/v1/me/unread -> harus 0
      const unreadSeller2 = await request(app)
        .get('/api/v1/me/unread')
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(unreadSeller2.body.data.chats).toBe(0);
    });
  });

  describe('POST /api/v1/conversations/:id/whatsapp', () => {
    let allowedConvId;
    let disallowedConvId;

    beforeEach(() => {
      const convAllowed = db.addConv({
        listing_id: 13, // izinkan_wa: true
        buyer_id: 1,
        seller_id: 2,
      });
      allowedConvId = convAllowed.id;

      const convDisallowed = db.addConv({
        listing_id: 10, // izinkan_wa: false
        buyer_id: 1,
        seller_id: 2,
      });
      disallowedConvId = convDisallowed.id;
    });

    it('menolak akses tanpa autentikasi (401)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${allowedConvId}/whatsapp`);

      expect(res.status).toBe(401);
    });

    it('menolak akses pengguna luar yang bukan peserta percakapan (404)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${allowedConvId}/whatsapp`)
        .set('Authorization', `Bearer ${otherToken}`);

      expect(res.status).toBe(404);
    });

    it('menolak jika percakapan tidak ditemukan (404)', async () => {
      const res = await request(app)
        .post('/api/v1/conversations/999999/whatsapp')
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(404);
    });

    it('menolak jika diakses oleh penjual (khusus pembeli) (403)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${allowedConvId}/whatsapp`)
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.message).toContain('tidak mengizinkan');
    });

    it('menolak jika listing tidak mengizinkan WhatsApp (403 FORBIDDEN)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${disallowedConvId}/whatsapp`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
      expect(res.body.error.message).toContain('tidak mengizinkan');
    });

    it('menolak jika ada pemblokiran di antara kedua pihak BR-12 (403 BLOCKED)', async () => {
      db.blocks.push({ blocker_id: 2, blocked_id: 1 });

      const res = await request(app)
        .post(`/api/v1/conversations/${allowedConvId}/whatsapp`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('BLOCKED');
    });

    it('mengembalikan wa_url yang valid jika pembeli meminta dan izin WA aktif (200)', async () => {
      const res = await request(app)
        .post(`/api/v1/conversations/${allowedConvId}/whatsapp`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('wa_url');

      const waUrl = res.body.data.wa_url;
      expect(waUrl.startsWith('https://wa.me/6281234567890?text=')).toBe(true);

      const parsed = new URL(waUrl);
      const textParam = parsed.searchParams.get('text');
      expect(textParam).toContain('Pembeli Satu');
      expect(textParam).toContain('Konser Sheila on 7');
      expect(textParam).toContain('WIB');
    });
  });

  describe('Batas Laju (Rate Limiting)', () => {
    it('menolak pengiriman pesan melebihi 30 pesan per menit (429)', async () => {
      const rateLimitedApp = createApp({ db, useRateLimit: true });

      const conv = db.addConv({
        listing_id: 10,
        buyer_id: 1,
        seller_id: 2,
      });

      // Kirim 30 pesan berturut-turut
      for (let i = 0; i < 30; i++) {
        const res = await request(rateLimitedApp)
          .post(`/api/v1/conversations/${conv.id}/messages`)
          .set('Authorization', `Bearer ${buyerToken}`)
          .send({ isi: `Pesan ke-${i + 1}` });
        expect(res.status).toBe(201);
      }

      // Pesan ke-31 harus terkena 429 RATE_LIMITED
      const resLimit = await request(rateLimitedApp)
        .post(`/api/v1/conversations/${conv.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ isi: 'Pesan ke-31' });

      expect(resLimit.status).toBe(429);
      expect(resLimit.body.error.code).toBe('RATE_LIMITED');
    });
  });
});
