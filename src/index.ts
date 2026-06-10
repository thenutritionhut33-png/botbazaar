import app from './server';

const PORT = process.env['PORT'] ? parseInt(process.env['PORT'], 10) : 3000;

app.listen(PORT, () => {
  console.log(`BotBazaar server running on port ${PORT}`);
});
