const express = require('express');
const app = express();
app.use(express.json())
const { Wechaty } = require('wechaty')
const WECHATY_PUPPET_HOSTIE_TOKEN = require('./puppet.js')

const puppet = 'wechaty-puppet-hostie' // 使用ipad 的方式接入。

const puppetOptions = {
  token: WECHATY_PUPPET_HOSTIE_TOKEN,
}


app.get('/', (req, res) => {
  res.send('Hello World!');
});
app.post('/send_message', async (req, res) => {
  const room = await BOT.Room.find({topic: req.body.name})
  if (room) {
    await room.say(req.body.message)
  }
  res.send('Hello World!');
})

app.listen(63000, () => {
  console.log('示例应用正在监听 3000 端口!');
  BOT = new Wechaty({
    puppet,
    puppetOptions,
  }) // Singleton
  BOT.on('scan',     (qrcode, status)  => console.log(`Scan QR Code to login: ${status}\nhttps://wechaty.js.org/qrcode/${encodeURIComponent(qrcode)}`))
  BOT.on('login',    user              => console.log(`User ${user} logined`))
  BOT.on('message',  message           => console.log(`Message: ${message}`))
  .start().catch(console.error)
});