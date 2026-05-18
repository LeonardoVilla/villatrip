import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import mongoose from 'mongoose';

const app = express();
app.use(cors());
app.use(express.json());

const placeSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    location: { type: String, required: true },
    openingTime: { type: String, required: true },
    closingTime: { type: String, required: true },
    commuteDuration: { type: String, required: true },
    transportSchedule: { type: String, required: true },
    visited: { type: Boolean, default: false },
    updatedAt: { type: String, required: true },
  },
  { versionKey: false },
);

const Place = mongoose.model('Place', placeSchema);

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.get('/api/places', async (_req, res) => {
  const places = await Place.find().sort({ visited: 1, name: 1 }).lean();
  res.json({ places });
});

app.post('/api/places/upsert', async (req, res) => {
  const payload = req.body ?? {};

  const data = {
    name: payload.name,
    location: payload.location,
    openingTime: payload.openingTime,
    closingTime: payload.closingTime,
    commuteDuration: payload.commuteDuration,
    transportSchedule: payload.transportSchedule,
    visited: Boolean(payload.visited),
    updatedAt: payload.updatedAt ?? new Date().toISOString(),
  };

  let place;
  if (payload._id) {
    place = await Place.findByIdAndUpdate(payload._id, data, {
      new: true,
      runValidators: true,
    });
    if (!place) {
      place = await Place.create(data);
    }
  } else {
    place = await Place.create(data);
  }

  res.json({ place });
});

app.delete('/api/places/:id', async (req, res) => {
  await Place.findByIdAndDelete(req.params.id);
  res.json({ deleted: true });
});

async function main() {
  const mongoUri = process.env.MONGO_URI;
  const port = Number(process.env.PORT ?? 3000);

  if (!mongoUri) {
    throw new Error('Defina MONGO_URI no arquivo .env');
  }

  await mongoose.connect(mongoUri);
  app.listen(port, () => {
    console.log(`API Mongo rodando em http://localhost:${port}`);
  });
}

main().catch((error) => {
  console.error('Erro ao iniciar API:', error);
  process.exit(1);
});
