import React, { useState, useEffect, useRef } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, ScrollView,
  StyleSheet, Platform, Alert, Vibration, Animated,
  Modal, Dimensions, AppState, StatusBar, Linking,
  NativeModules
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Notifications from 'expo-notifications';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';

const { LockTaskModule, StickyServiceModule } = NativeModules;

const { width, height } = Dimensions.get('window');

const STORAGE_KEY   = '@yaad_sentences';
const INTERVAL_KEY  = '@yaad_interval';
const NEXT_TIME_KEY = '@yaad_next_time';
const ERROR_LOG_KEY = '@yaad_logs';

const INTERVALS = [
  { label: '۱ دقیقه',  value: 60   },
  { label: '۵ دقیقه',  value: 300  },
  { label: '۱۵ دقیقه', value: 900  },
  { label: '۳۰ دقیقه', value: 1800 },
  { label: '۱ ساعت',   value: 3600 },
];

const PALETTES = [
  ['#FF6B6B', '#4ECDC4', '#45B7D1'],
  ['#A8E6CF', '#DCEDC1', '#FFD3B6'],
  ['#FF9A9E', '#FECFEF', '#FDE2E4'],
  ['#FAD961', '#F76B1C', '#FF6B6B'],
  ['#667EEA', '#764BA2', '#F093FB'],
  ['#43E97B', '#38F9D7', '#12B0E8'],
  ['#FA709A', '#FEE140', '#F76B1C'],
  ['#B224EF', '#7579FF', '#E2B0FF'],
];

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
    priority: Notifications.AndroidNotificationPriority.MAX,
  }),
});

export default function App() {
  const [inputText, setInputText]     = useState('');
  const [sentences, setSentences]     = useState([]);
  const [isRunning, setIsRunning]     = useState(false);
  const [selInterval, setSelInterval] = useState(INTERVALS[2]);
  const [customMinutes, setCustomMinutes] = useState('');
  const [lockSeconds, setLockSeconds] = useState(10);
  const [lockSecondsInput, setLockSecondsInput] = useState('');
  const lockSecondsRef = useRef(10);
  lockSecondsRef.current = lockSeconds;
  const [status, setStatus]           = useState('غیرفعال');
  const [nextTime, setNextTime]       = useState('');
  const [logs, setLogs]               = useState([]);
  const [showSplash, setShowSplash]   = useState(true);
  const [splashText, setSplashText]   = useState('');
  const fadeAnim                      = useRef(new Animated.Value(0)).current;
  const scaleAnim                     = useRef(new Animated.Value(0.9)).current;

  const [showPopup, setShowPopup]     = useState(false);
  const [popupText, setPopupText]     = useState('');
  const [palIdx, setPalIdx]           = useState(0);
  const popupFade                     = useRef(new Animated.Value(0)).current;
  const cdInterval                    = useRef(null);
  const [secsLeft, setSecsLeft]       = useState(10);

  const STICKY_NOTIF_ID = 'sticky_reminder';
  const appState = useRef(AppState.currentState);

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fadeAnim, { toValue: 1, duration: 1000, useNativeDriver: true }),
      Animated.spring(scaleAnim, { toValue: 1, friction: 5, useNativeDriver: true })
    ]).start();
    setTimeout(() => setShowSplash(false), 4000);
  }, []);

  // هندل کردن Deep Link از دکمه پنل بالای گوشی
  useEffect(() => {
    const handleDeepLink = (event) => {
      if (event.url && event.url.includes('popup')) {
        triggerRandomPopup();
      }
    };

    Linking.getInitialURL().then((url) => {
      if (url && url.includes('popup')) {
        triggerRandomPopup();
      }
    });

    const sub = Linking.addEventListener('url', handleDeepLink);
    return () => sub.remove();
  }, [sentences]);

  function triggerRandomPopup() {
    AsyncStorage.getItem(STORAGE_KEY).then((saved) => {
      const list = saved ? JSON.parse(saved) : sentences;
      if (list && list.length > 0) {
        const r = list[Math.floor(Math.random() * list.length)];
        openPopup(r);
        addLog('از دکمه بالای گوشی: ' + r.substring(0, 25) + '...');
        refreshLogs();
      }
    });
  }

  async function createStickyNotification() {
    if (Platform.OS !== 'android') return;
    await Notifications.dismissNotificationAsync(STICKY_NOTIF_ID);
    await Notifications.scheduleNotificationAsync({
      identifier: STICKY_NOTIF_ID,
      content: {
        title: '✨ یادآور جملات',
        body: 'برای نمایش جمله فوری کلیک کنید',
        sound: false,
        priority: Notifications.AndroidNotificationPriority.MAX,
        autoDismiss: false,
        android: {
          channelId: 'urgent_channel',
          sticky: true,
          ongoing: true,
          autoCancel: false,
        },
      },
      trigger: null,
    });
  }

  async function ensureNotificationExists() {
    const scheduled = await Notifications.getAllScheduledNotificationsAsync();
    const exists = scheduled.some(n => n.identifier === STICKY_NOTIF_ID);
    if (!exists) await createStickyNotification();
  }

  useEffect(() => {
    loadData();
    (async () => {
      // اضافه شد: پاک کردن یک‌باره کانال قدیمی که ممکنه با تنظیمات ضعیف قفل شده باشه
      await Notifications.deleteNotificationChannelAsync('urgent_channel').catch(() => {});
      configureChannel();
    })();
    checkActive();
    setTimeout(() => {
      Notifications.dismissNotificationAsync(STICKY_NOTIF_ID).catch(() => {});
      if (Platform.OS === 'android' && StickyServiceModule) {
        StickyServiceModule.startStickyService().catch(() => {});
      }
    }, 2000);

    // ثبت پکیج برای Lock Task
    if (Platform.OS === 'android' && LockTaskModule) {
      LockTaskModule.enableLockTaskPackage().catch(() => {});
    }

    const subscription = AppState.addEventListener('change', (nextAppState) => {
      if (appState.current.match(/inactive|background/) && nextAppState === 'active') {
        if (Platform.OS === 'android' && StickyServiceModule) { StickyServiceModule.startStickyService().catch(() => {}); }
      }
      appState.current = nextAppState;
    });

    const stickyWatcher = setInterval(() => {
      if (Platform.OS === 'android' && StickyServiceModule) { StickyServiceModule.startStickyService().catch(() => {}); }
    }, 60000);

    return () => {
      subscription.remove();
      clearInterval(cdInterval.current);
      clearInterval(stickyWatcher);
    };
  }, []);

  useEffect(() => {
    const subscription = Notifications.addNotificationResponseReceivedListener(async (response) => {
      if (response.notification.request.identifier === STICKY_NOTIF_ID) {
        if (sentences.length > 0) {
          const r = sentences[Math.floor(Math.random() * sentences.length)];
          openPopup(r);
          await addLog('از نوتیفیکیشن: ' + r.substring(0, 25) + '...');
          await refreshLogs();
          setTimeout(() => ensureNotificationExists(), 500);
        } else {
          Alert.alert('خطا', 'ابتدا جمله‌ای در برنامه وارد کنید');
        }
      }
    });
    return () => subscription.remove();
  }, [sentences]);

  function openPopup(sentence) {
    if (Platform.OS === 'android' && LockTaskModule) { LockTaskModule.startLockTask().catch(() => {}); }
    setPalIdx(Math.floor(Math.random() * PALETTES.length));
    setPopupText(sentence);
    setSecsLeft(lockSecondsRef.current);
    popupFade.setValue(0);
    setShowPopup(true);
    Animated.spring(popupFade, { toValue: 1, friction: 7, useNativeDriver: true }).start();
    Vibration.vibrate(200);

    // قفل کردن صفحه هنگام باز شدن پاپ‌آپ
    if (Platform.OS === 'android' && LockTaskModule) {
      LockTaskModule.startLockTask().catch((e) =>
        addLog('خطا در قفل صفحه: ' + e.message)
      );
    }

    clearInterval(cdInterval.current);
    cdInterval.current = setInterval(() => {
      setSecsLeft(p => {
        if (p <= 1) {
          clearInterval(cdInterval.current);
          
          // باز کردن قفل بعد از اتمام ۱۰ ثانیه
          if (Platform.OS === 'android' && LockTaskModule) {
            LockTaskModule.stopLockTask().catch(() => {});
          }

          return 0;
        }
        return p - 1;
      });
    }, 1000);
  }

  function closePopup() {
    if (Platform.OS === 'android' && LockTaskModule) { LockTaskModule.stopLockTask().catch(() => {}); }
    if (secsLeft > 0) return; // جلوگیری از خروج قبل از اتمام ۱۰ ثانیه
    if (Platform.OS === 'android' && LockTaskModule) {
      LockTaskModule.stopLockTask().catch(() => {});
    }
    clearInterval(cdInterval.current);
    Animated.timing(popupFade, { toValue: 0, duration: 400, useNativeDriver: true }).start(() => setShowPopup(false));
  }

  async function configureChannel() {
    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('urgent_channel', {
        name: 'یادآورها',
        importance: Notifications.AndroidImportance.MAX,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: '#4ECDC4',
        enableVibrate: true,
        enableLights: true,
        showBadge: true,
        sound: 'default',
        lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
        bypassDnd: true,
      });
    }
    try { await Notifications.requestPermissionsAsync(); } catch(e) {}
  }

  async function loadData() {
    try {
      const saved = await AsyncStorage.getItem(STORAGE_KEY);
      if (saved) {
        const list = JSON.parse(saved);
        setSentences(list);
        setInputText(list.join(' | '));
        if (list.length > 0) setSplashText(list[Math.floor(Math.random() * list.length)]);
      }
      const si = await AsyncStorage.getItem(INTERVAL_KEY);
      if (si) { const f = INTERVALS.find(i => i.value === parseInt(si)); if (f) setSelInterval(f); }
      const st = await AsyncStorage.getItem(NEXT_TIME_KEY);
      if (st) setNextTime(st);
      await refreshLogs();
    } catch(e) {}
  }

  async function addLog(msg) {
    try {
      const t = new Date().toLocaleTimeString('fa-IR', { hour:'2-digit', minute:'2-digit', second:'2-digit' });
      const full = '[' + t + '] ' + msg;
      const prev = await AsyncStorage.getItem(ERROR_LOG_KEY);
      let arr = prev ? JSON.parse(prev) : [];
      arr.unshift(full);
      if (arr.length > 30) arr.pop();
      await AsyncStorage.setItem(ERROR_LOG_KEY, JSON.stringify(arr));
    } catch(e) {}
  }

  async function refreshLogs() {
    const s = await AsyncStorage.getItem(ERROR_LOG_KEY);
    setLogs(s ? JSON.parse(s) : ['✨ به یادآور خوش آمدی']);
  }

  async function clearLogs() {
    await AsyncStorage.removeItem(ERROR_LOG_KEY);
    setLogs(['📋 لاگ پاک شد']);
  }

  async function checkActive() {
    const s = await Notifications.getAllScheduledNotificationsAsync();
    const on = s.length > 0;
    setIsRunning(on);
    setStatus(on ? 'فعال ✅' : 'غیرفعال');
    if (!on) setNextTime('');
  }

  async function saveSentences() {
    const list = inputText.split('|').map(s => s.trim()).filter(s => s.length > 0);
    if (list.length === 0) { Alert.alert('خطا', 'حداقل یک جمله وارد کنید.'); return null; }
    setSentences(list);
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(list));
    await AsyncStorage.setItem(INTERVAL_KEY, String(selInterval.value));
    return list;
  }

  async function quickReminder() {
    if (sentences.length === 0) { Alert.alert('خطا', 'ابتدا جمله‌ای بنویسید.'); return; }
    const r = sentences[Math.floor(Math.random() * sentences.length)];
    openPopup(r);
    await addLog('پاپ‌آپ: ' + r.substring(0, 25) + '...');
    await refreshLogs();
  }

  async function testNotif() {
    const list = inputText.split('|').map(s => s.trim()).filter(s => s.length > 0);
    if (list.length === 0) { Alert.alert('خطا', 'ابتدا جمله‌ای بنویسید.'); return; }
    try {
      const r = list[Math.floor(Math.random() * list.length)];
      await Notifications.scheduleNotificationAsync({
        content: { title: '🎉 تست', body: r, sound: true, priority: Notifications.AndroidNotificationPriority.MAX, android: { channelId: 'urgent_channel' } },
        trigger: null,
      });
      await addLog('تست شلیک شد: ' + r.substring(0, 25));
      await refreshLogs();
    } catch(e) { await addLog('خطا: ' + e.message); await refreshLogs(); }
  }

  async function startNotifs() {
    const list = await saveSentences();
    if (!list) return;
    try {
      await Notifications.cancelAllScheduledNotificationsAsync();
      const r0 = list[Math.floor(Math.random() * list.length)];
      await Notifications.scheduleNotificationAsync({
        content: { title: '🌟 شروع یادآورها', body: r0, sound: true, priority: Notifications.AndroidNotificationPriority.MAX, android: { channelId: 'urgent_channel' } },
        trigger: null,
      });
      const sec = selInterval.value;
      for (let i = 1; i <= 200; i++) {
        const r = list[Math.floor(Math.random() * list.length)];
        await Notifications.scheduleNotificationAsync({
          content: { title: '🔔 یادآور', body: r, sound: true, priority: Notifications.AndroidNotificationPriority.MAX, android: { channelId: 'urgent_channel' } },
          trigger: { type: 'timeInterval', seconds: sec * i, repeats: false },
        });
      }
      const nt = new Date(Date.now() + sec * 1000);
      const ts = nt.toLocaleTimeString('fa-IR', { hour:'2-digit', minute:'2-digit' });
      setNextTime(ts);
      await AsyncStorage.setItem(NEXT_TIME_KEY, ts);
      setIsRunning(true);
      setStatus('فعال ✅');
      await addLog('زمان‌بندی شروع شد — ' + selInterval.label);
      await refreshLogs();
    } catch(e) { await addLog('خطا: ' + e.message); await refreshLogs(); }
  }

  async function stopNotifs() {
    await Notifications.cancelAllScheduledNotificationsAsync();
    setIsRunning(false); setStatus('غیرفعال'); setNextTime('');
    await AsyncStorage.removeItem(NEXT_TIME_KEY);
    await addLog('زمان‌بندی لغو شد.');
    await refreshLogs();
  }

  if (showSplash) {
    return (
      <LinearGradient colors={['#667EEA', '#764BA2']} style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <StatusBar barStyle="light-content" />
        <Animated.View style={{ opacity: fadeAnim, transform: [{ scale: scaleAnim }], alignItems: 'center' }}>
          <Ionicons name="bulb-outline" size={80} color="#FFF" style={{ marginBottom: 20 }} />
          <Text style={{ color: '#fff', fontSize: 32, fontWeight: 'bold', textAlign: 'center', marginBottom: 20 }}>
            {splashText || 'یادآور جملات'}
          </Text>
          <Text style={{ color: '#FFE0B5', fontSize: 16, marginBottom: 50, textAlign: 'center' }}>
            لحظاتت را با جملات زیبا بساز
          </Text>
          <TouchableOpacity onPress={() => setShowSplash(false)} style={{ backgroundColor: '#fff', paddingHorizontal: 35, paddingVertical: 12, borderRadius: 30, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.3, shadowRadius: 5, elevation: 5 }}>
            <Text style={{ color: '#764BA2', fontSize: 18, fontWeight: '700' }}>شروع کن 🚀</Text>
          </TouchableOpacity>
        </Animated.View>
      </LinearGradient>
    );
  }

  const pal = PALETTES[palIdx];
  return (
    <>
      <StatusBar barStyle="dark-content" />
      <Modal
        visible={showPopup}
        transparent
        animationType="none"
        statusBarTranslucent
        onRequestClose={() => {
          if (secsLeft === 0) closePopup();
        }}
      >
        <LinearGradient colors={pal} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.overlay}>
          <Animated.View style={[styles.popupBox, { opacity: popupFade, transform: [{ scale: popupFade }] }]}>
            <View style={styles.cdBadge}>
              <Text style={styles.cdText}>{secsLeft > 0 ? secsLeft : '✓'}</Text>
            </View>
            <View style={styles.line} />
            <Text style={styles.popupSentence}>{popupText}</Text>
            <View style={styles.line} />
            <Text style={styles.popupHint}>✨ فقط یک قدم جلوتر برو ✨</Text>

            {/* شرط نمایش دکمه بستن فقط پس از اتمام ۱۰ ثانیه */}
            {secsLeft > 0 ? (
              <View style={styles.lockBadge}>
                <Ionicons name="lock-closed" size={16} color="#FFE0B5" style={{ marginLeft: 6 }} />
                <Text style={styles.lockText}>{'لطفاً ' + lockSeconds + ' ثانیه صبور باشید...'}</Text>
              </View>
            ) : (
              <TouchableOpacity style={styles.closeBtn} onPress={closePopup} activeOpacity={0.8}>
                <Text style={styles.closeBtnText}>بستن ✕</Text>
              </TouchableOpacity>
            )}
          </Animated.View>
        </LinearGradient>
      </Modal>

      <ScrollView contentContainerStyle={styles.container}>
        <LinearGradient colors={['#667EEA', '#764BA2']} style={styles.headerGradient}>
          <Text style={styles.title}>✨ یادآور جملات ✨</Text>
          <TouchableOpacity style={styles.headerBtn} onPress={quickReminder}>
            <Ionicons name="flash" size={20} color="#fff" />
            <Text style={styles.headerBtnText}>جمله فوری</Text>
          </TouchableOpacity>
        </LinearGradient>

        <View style={styles.card}>
          <View style={[styles.badge, isRunning ? styles.badgeOn : styles.badgeOff]}>
            <Text style={styles.badgeText}>{status}</Text>
          </View>
          {isRunning && nextTime ? (
            <View style={styles.timeBadge}>
              <Text style={styles.timeBadgeText}>⏰ ارسال بعدی: {nextTime}</Text>
            </View>
          ) : null}

          <Text style={styles.label}>📝 جملات خود را وارد کن (با | جدا کن)</Text>
          <TextInput
            style={styles.input}
            multiline
            value={inputText}
            onChangeText={setInputText}
            placeholder="جمله اول | جمله دوم | جمله سوم ..."
            textAlign="right"
            placeholderTextColor="#aaa"
          />
          <Text style={styles.hint}>📚 تعداد جملات: {sentences.length}</Text>

          <Text style={styles.label}>⏱️ فاصله زمانی</Text>
          <View style={styles.pills}>
            {INTERVALS.map(item => (
              <TouchableOpacity
                key={item.value}
                style={[styles.pill, selInterval.value === item.value && styles.pillOn]}
                onPress={() => setSelInterval(item)}>
                <Text style={[styles.pillTxt, selInterval.value === item.value && styles.pillTxtOn]}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.label}>🔧 یا فاصله دلخواه (به دقیقه)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={styles.customInput}
              keyboardType="numeric"
              value={customMinutes}
              onChangeText={setCustomMinutes}
              placeholder="مثلاً 7"
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={() => {
                const mins = parseInt(customMinutes, 10);
                if (!mins || mins <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای دقیقه وارد کن');
                  return;
                }
                setSelInterval({ label: mins + ' دقیقه (دلخواه)', value: mins * 60 });
              }}>
              <Text style={styles.customBtnText}>تنظیم</Text>
            </TouchableOpacity>
          </View>

          <Text style={styles.label}>🔒 مدت قفل پاپ‌آپ (به ثانیه)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={styles.customInput}
              keyboardType="numeric"
              value={lockSecondsInput}
              onChangeText={setLockSecondsInput}
              placeholder={'پیش‌فرض: ' + lockSeconds}
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={() => {
                const secs = parseInt(lockSecondsInput, 10);
                if (!secs || secs <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای ثانیه وارد کن');
                  return;
                }
                setLockSeconds(secs);
                Alert.alert('انجام شد', 'پاپ‌آپ از این به بعد ' + secs + ' ثانیه قفل می‌مونه');
              }}>
              <Text style={styles.customBtnText}>تنظیم</Text>
            </TouchableOpacity>
          </View>

          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>
            <Ionicons name="git-compare" size={22} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>جمله فوری</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.btnRed} onPress={testNotif}>
            <Ionicons name="notifications" size={22} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>تست نوتیفیکیشن</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.btnBlue} onPress={startNotifs}>
            <Ionicons name="play" size={22} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>شروع زمان‌بندی</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.btnGray} onPress={stopNotifs}>
            <Ionicons name="stop" size={22} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>لغو و توقف</Text>
          </TouchableOpacity>

          <View style={styles.logBox}>
            <View style={styles.logHdr}>
              <TouchableOpacity onPress={clearLogs}><Text style={styles.logClear}>🗑️ پاک کردن</Text></TouchableOpacity>
              <Text style={styles.logTitle}>📋 رویدادها</Text>
              <TouchableOpacity onPress={refreshLogs}><Text style={styles.logRefresh}>🔄 به‌روز</Text></TouchableOpacity>
            </View>
            <ScrollView style={styles.logScroll}>
              {logs.map((l, i) => (
                <Text key={i} style={[styles.logTxt, l.includes('خطا') && styles.logErr]}>{l}</Text>
              ))}
            </ScrollView>
          </View>
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  overlay: { flex: 1, width, height, justifyContent: 'center', alignItems: 'center', paddingHorizontal: 28, backgroundColor: 'rgba(0,0,0,0.6)' },
  popupBox: { width: '100%', alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.3)', borderRadius: 40, padding: 20 },
  cdBadge: { width: 60, height: 60, borderRadius: 30, backgroundColor: 'rgba(255,255,255,0.2)', borderWidth: 2, borderColor: '#fff', justifyContent: 'center', alignItems: 'center', marginBottom: 20 },
  cdText: { color: '#fff', fontSize: 24, fontWeight: 'bold' },
  line: { width: 80, height: 2, backgroundColor: 'rgba(255,255,255,0.3)', borderRadius: 2, marginVertical: 20 },
  popupSentence: { color: '#fff', fontSize: 28, fontWeight: '800', textAlign: 'center', lineHeight: 44, textShadowColor: 'rgba(0,0,0,0.3)', textShadowOffset: { width: 1, height: 2 }, textShadowRadius: 6 },
  popupHint: { color: '#FFE0B5', fontSize: 16, marginTop: 10, marginBottom: 30, fontStyle: 'italic' },
  closeBtn: { backgroundColor: '#fff', paddingHorizontal: 35, paddingVertical: 12, borderRadius: 40, shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.2, shadowRadius: 4, elevation: 3 },
  closeBtnText: { color: '#764BA2', fontSize: 16, fontWeight: 'bold' },
  lockBadge: { flexDirection: 'row-reverse', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.15)', paddingHorizontal: 20, paddingVertical: 10, borderRadius: 30 },
  lockText: { color: '#FFE0B5', fontSize: 14, fontWeight: '600' },

  container: { flexGrow: 1, backgroundColor: '#F0F4F8', paddingBottom: 30 },
  headerGradient: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: Platform.OS === 'ios' ? 60 : 40, paddingBottom: 20, borderBottomLeftRadius: 30, borderBottomRightRadius: 30, elevation: 5, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 5 },
  title: { fontSize: 24, fontWeight: 'bold', color: '#fff', letterSpacing: 1 },
  headerBtn: { flexDirection: 'row', backgroundColor: 'rgba(255,255,255,0.25)', paddingVertical: 8, paddingHorizontal: 16, borderRadius: 30, alignItems: 'center', gap: 8 },
  headerBtnText: { color: '#fff', fontSize: 14, fontWeight: '600' },

  card: { backgroundColor: '#fff', margin: 20, marginTop: 20, borderRadius: 30, padding: 20, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.1, shadowRadius: 10, elevation: 6 },
  badge: { alignSelf: 'center', paddingHorizontal: 20, paddingVertical: 6, borderRadius: 30, marginBottom: 12 },
  badgeOn: { backgroundColor: '#E0F2FE' },
  badgeOff: { backgroundColor: '#F1F5F9' },
  badgeText: { fontSize: 14, fontWeight: '600', color: '#1E293B' },
  timeBadge: { alignSelf: 'center', backgroundColor: '#FEF9C3', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 30, marginBottom: 20, borderWidth: 1, borderColor: '#FDE047' },
  timeBadgeText: { fontSize: 14, fontWeight: '700', color: '#A16207' },
  label: { fontSize: 15, fontWeight: '600', color: '#334155', marginBottom: 8, marginTop: 10, textAlign: 'right' },
  input: { backgroundColor: '#F8FAFC', borderWidth: 1, borderColor: '#E2E8F0', borderRadius: 20, padding: 14, fontSize: 15, minHeight: 120, textAlignVertical: 'top', color: '#0F172A', marginBottom: 6 },
  hint: { fontSize: 12, color: '#64748B', textAlign: 'right', marginBottom: 20 },
  pills: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'flex-end', gap: 8, marginBottom: 24 },
  pill: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: 30, backgroundColor: '#F1F5F9', borderWidth: 0 },
  pillOn: { backgroundColor: '#6366F1' },
  pillTxt: { fontSize: 13, fontWeight: '500', color: '#334155' },
  pillTxtOn: { color: '#fff' },
  customRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 24 },
  customInput: { flex: 1, backgroundColor: '#F8FAFC', borderWidth: 1, borderColor: '#E2E8F0', borderRadius: 20, padding: 12, fontSize: 15, color: '#0F172A' },
  customBtn: { backgroundColor: '#0EA5E9', borderRadius: 20, paddingHorizontal: 16, paddingVertical: 12 },
  customBtnText: { color: '#fff', fontSize: 13, fontWeight: '700' },

  btnPurple: { backgroundColor: '#8B5CF6', borderRadius: 40, paddingVertical: 14, alignItems: 'center', marginBottom: 12, flexDirection: 'row', justifyContent: 'center', gap: 8, shadowColor: '#8B5CF6', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.3, shadowRadius: 5, elevation: 4 },
  btnRed: { backgroundColor: '#EF4444', borderRadius: 40, paddingVertical: 14, alignItems: 'center', marginBottom: 12, flexDirection: 'row', justifyContent: 'center', gap: 8, shadowColor: '#EF4444', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.3, shadowRadius: 5, elevation: 4 },
  btnBlue: { backgroundColor: '#3B82F6', borderRadius: 40, paddingVertical: 14, alignItems: 'center', marginBottom: 12, flexDirection: 'row', justifyContent: 'center', gap: 8, shadowColor: '#3B82F6', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.3, shadowRadius: 5, elevation: 4 },
  btnGray: { backgroundColor: '#64748B', borderRadius: 40, paddingVertical: 14, alignItems: 'center', marginBottom: 24, flexDirection: 'row', justifyContent: 'center', gap: 8, shadowColor: '#64748B', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.3, shadowRadius: 5, elevation: 4 },
  btnTxt: { color: '#fff', fontSize: 16, fontWeight: '700' },

  logBox: { backgroundColor: '#1E293B', borderRadius: 28, padding: 16, marginTop: 10 },
  logHdr: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: '#475569', paddingBottom: 10, marginBottom: 10 },
  logTitle: { color: '#FACC15', fontSize: 14, fontWeight: '700' },
  logRefresh: { color: '#38BDF8', fontSize: 12, fontWeight: '600' },
  logClear: { color: '#F87171', fontSize: 12 },
  logScroll: { maxHeight: 150, minHeight: 80 },
  logTxt: { color: '#CBD5E1', fontSize: 12, textAlign: 'left', marginBottom: 4, fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace' },
  logErr: { color: '#F87171', fontWeight: '700' },
});
