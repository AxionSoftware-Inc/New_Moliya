# 💰 New_Moliya: Minimalist Kassa, Nasiyalar Daftari va Cashflow

> **Business Ecosystem** loyihasining moliyaviy hisob-kitob, kassa kirim/chiqimi, nasiya/qarzlar daftari va P&L hisoboti ilovasi.
> GitHub Repozitoriy: [https://github.com/AxionSoftware-Inc/New_Moliya.git](https://github.com/AxionSoftware-Inc/New_Moliya.git)

---

## 🏛 Arxitektura va Dizayn

Dastur **Mikroyadro (Microkernel)** va **Qat'iy 3-Tab Minimalist** standartida qurilgan:

```
┌─────────────────────────────────────────────────────────────┐
│  APPBAR: [💰 Moliya & Kassa]   [👤 Malika (Kassir)]   [✨ AI]   [:8083] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Tab 0: Kassa & Balans] [Tab 1: Kirim/Chiqim]   [Tab 2: Profil]│
│  ──────────────────────  ────────────────────    ───────────────│
│  • Kassa Sof Qoldig'i    • Operatsiya turi       • Kassir/Buxg. │
│  • P&L Tahlil Plagini    • Summa (so'm)          • Rol Sinash   │
│  • Qarzlar Daftari       • Kimdan / Kimga        • Server Porti │
│  • Tranzaksiyalar tarixi • Toifa (ijara, savdo)  • Plaginlar    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚡ Plaginlar Tizimi (Microkernel Extensions)

1. **P&L Tahlil va Rentabellik Plagini (`plugin_pnl_analytics`):**
   - Real-vaqtda kassa rentabelligi (`Sof Foyda / Jami Kirim * 100`) va xarajatlar toifasini ko'rsatadi.
2. **Nasiyalar va Qarzlar Daftari (`plugin_debt_ledger`):**
   - Mijozlar va ta'minotchilar bilan debitorlik/kreditorlik hisobini yuritadi. Qarz to'langanda kassa qoldig'ini avtomat oshiradi.
3. **Ekotizim Integratsiyasi (`plugin_ecosystem_bridge`):**
   - KPI'da tasdiqlangan bonuslar avtomatik ushbu serverga chiqim bo'lib tushadi.
   - CRM'da yutilgan bitimlar avtomatik kassa kirimi bo'lib qayd etiladi.
4. **AI Kassa Yordamchisi (`plugin_uzbek_ai`):**
   - Tabiiy tilda yozilgan amallarni toifalaydi:
     *"Alidan 5 000 000 so'm qarz qaytdi, kassaga kirim qil"* yoki *"Ofis ijarasiga 2 000 000 chiqim yoz"*.

---

## 🔐 Rollar va RBAC Xavfsizlik Matritsasi

| Harakat | Kassir (Malika) | Buxgalter | Direktor |
| :--- | :---: | :---: | :---: |
| Kassa balansini ko'rish | ✅ | ✅ | ✅ |
| Kirim / Chiqim kiritish | ✅ | ✅ | ✅ |
| Qarz yozish va to'lov olish | ✅ | ✅ | ✅ |
| Moliyaviy yozuvni o'chirish | ❌ | ❌ | ✅ |
| Hisobotlarni eksport qilish | ❌ | ✅ | ✅ |

---

## 🌐 Microservice HTTP API (:8083)

- `GET http://localhost:8083/health` - Kassa server holati.
- `GET http://localhost:8083/schema` - Barcha moliya tools va parametrlar.
- `GET http://localhost:8083/export` - Kassa yozuvlari JSON eksporti.
- `POST http://localhost:8083/execute` - Funksiya bajarish:
  ```json
  {
    "action": "finance_income",
    "params": {
      "amount": 5000000,
      "from": "Ali",
      "category": "savdo",
      "note": "ERP Tizimi sotuvidan tushum",
      "cashier": "Malika"
    }
  }
  ```

---

## 🚀 O'rnatish va Ishga Tushirish (Mustaqil / Standalone)

```bash
# 1. Paketlarni olish
flutter pub get

# 2. Ishga tushirish
flutter run -d windows

# 3. Testlarni tekshirish (27 ta test)
dart run bin/test_finance.dart
```
