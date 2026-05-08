# Microsoft Entra ID Production Setup Guide

## 🔧 ขั้นตอนการตั้งค่า Entra ID สำหรับ Production

### 1️⃣ **สร้าง Entra ID Tenant**
1. ไปที่ [Microsoft Entra Admin Center](https://entra.microsoft.com/)
2. สร้าง tenant ใหม่หรือใช้ tenant ที่มีอยู่แล้ว
3. บันทึก **Tenant ID** สำหรับใช้ใน environment variables

### 2️⃣ **สร้าง App Registration**
1. ใน Entra ID Portal → **App registrations** → **New registration**
2. **Name**: `Spree Storefront SSO`
3. **Supported account types**: `Accounts in any organizational directory (Any Azure AD directory - Multitenant)`
4. **Redirect URI**: `https://your-storefront-domain.com/api/auth/callback/entra-id`
5. คลิก **Register**

### 3️⃣ **ตั้งค่า Authentication**
1. ใน App registration → **Authentication**
2. **Implicit grant and hybrid flows**: เปิดใช้งาน
   - ✅ Access tokens (used for implicit flows)
   - ✅ ID tokens (used for implicit and hybrid flows)
3. **Redirect URIs**: เพิ่ม production URL
   - `https://your-storefront-domain.com/api/auth/callback/entra-id`

### 4️⃣ **ตั้งค่า API Permissions**
1. ใน App registration → **API permissions**
2. **Add a permission** → **Microsoft Graph**
3. **Delegated permissions**:
   - `User.Read` - เพื่ออ่านข้อมูลผู้ใช้
   - `email` - เพื่ออ่าน email address
   - `profile` - เพื่ออ่าน profile information
4. **Grant admin consent** สำหรับ permissions

### 5️⃣ **สร้าง Client Secret**
1. ใน App registration → **Certificates & secrets**
2. **New client secret**
3. **Description**: `Spree SSO Production`
4. **Expires**: เลือกระยะเวลาที่เหมาะสม
5. บันทึก **Secret Value** ทันที (จะแสดงครั้งเดียว)

### 6️⃣ **บันทึกข้อมูลที่จำเป็น**
```
Tenant ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client Secret: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 7️⃣ **ตั้งค่า Environment Variables**

#### Spree Backend (.env.production)
```bash
ENTRA_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENTRA_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENTRA_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### Storefront (.env.production)
```bash
ENTRA_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENTRA_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENTRA_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

NEXT_PUBLIC_ENTRA_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
NEXT_PUBLIC_ENTRA_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

NEXTAUTH_URL=https://your-storefront-domain.com
```

## 🧪 ทดสอบ Configuration

### 1️⃣ **ทดสอบ OAuth Flow**
```bash
# ทดสอบ authorization URL
https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/authorize?client_id={client_id}&response_type=code&redirect_uri=https://your-storefront-domain.com/api/auth/callback/entra-id&response_mode=query&scope=openid%20profile%20email%20offline_access&state=random_string
```

### 2️⃣ **ทดสอบ Token Exchange**
```bash
curl -X POST "https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&client_id={client_id}&client_secret={client_secret}&code=auth_code&redirect_uri=https://your-storefront-domain.com/api/auth/callback/entra-id"
```

### 3️⃣ **ทดสอบ User Info**
```bash
curl -X GET "https://graph.microsoft.com/v1.0/me" \
  -H "Authorization: Bearer {access_token}"
```

## 🚨 Security Considerations

### **Client Secret Management**
- ✅ ใช้ environment variables หรือ secret management service
- ✅ หมุน client secret ทุก 6-12 เดือน
- ✅ ไม่เก็บ secrets ใน version control

### **Redirect URI Security**
- ✅ ใช้ HTTPS เท่านั้น
- ✅ ตรวจสอบว่า redirect URI ถูกต้อง
- ✅ ใช้ production domain ที่เป็นทางการ

### **Token Validation**
- ✅ ตรวจสอบ token expiration
- ✅ ตรวจสอบ issuer และ audience
- ✅ ใช้ proper JWT validation

## 🔍 Troubleshooting

### **Common Issues**
1. **AADSTS50011**: Redirect URI ไม่ตรงกับที่ตั้งค่าไว้
2. **AADSTS700016**: Application ไม่พบใน tenant
3. **AADSTS50001**: Resource ไม่พบหรือไม่ได้เปิดใช้งาน

### **Debug Steps**
1. ตรวจสอบ tenant ID, client ID, และ redirect URI
2. ตรวจสอบว่า app registration ถูกต้อง
3. ตรวจสอบว่า permissions ได้รับการ grant
4. ตรวจสอบว่า client secret ยังไม่หมดอายุ
