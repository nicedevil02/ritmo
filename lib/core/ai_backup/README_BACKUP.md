# AI Subsystem Backup (Ritmo)

این پوشه حاوی نسخهٔ پشتیبان کامل از ماژول‌های هستهٔ هوش مصنوعی پیش از تفکیک اسلات‌ها (`AiSlot.assistant` و `AiSlot.features`) می‌باشد.

## فایل‌های پشتیبان:
- `ai_gateway_backup.dart`: نسخه اصلی گیت‌وی
- `ai_connection_models_backup.dart`: نسخه اصلی مدل‌ها و کانفیگ‌ها
- `ai_connection_repository_backup.dart`: نسخه اصلی مخزن تنظیمات و کلیدها
- `streaming_chat_service_backup.dart`: نسخه اصلی سرویس چت استریم
- `ai_briefing_service_backup.dart`: نسخه اصلی سرویس بریفینگ هوشمند

## راهنمای بازگردانی:
در صورت نیاز به بازگردانی به وضعیت اولیه، کافی است محتوای فایل‌های backup را در فایل‌های متناظر در `lib/core/ai/` جایگزین نمایید.
