importScripts('https://www.gstatic.com/firebasejs/13.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.3.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDhheS0I6mMsOmQJalwCMMfQtw1Tf48TmY',
  authDomain: 'marawis-smpn-99.firebaseapp.com',
  projectId: 'marawis-smpn-99',
  storageBucket: 'marawis-smpn-99.firebasestorage.app',
  messagingSenderId: '482698289502',
  appId: '1:482698289502:web:32bc392bbdd0aa278eefcf',
  measurementId: 'G-RZQTDNW4PH'
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Marawis SMPN 99';
  self.registration.showNotification(title, {
    body: payload.notification?.body || 'Ada pengingat baru untuk kamu.',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: '/marawis-smpn99-app./' }
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = event.notification.data?.url || '/marawis-smpn99-app./';
  event.waitUntil(self.clients.openWindow(target));
});
