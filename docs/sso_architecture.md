# SSO Architecture สำหรับ Spree Storefront ด้วย Entra External ID (B2C)

## 🏗️ ภาพรวมของระบบ

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SSO Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐    ┌────────────────┐    ┌─────────┐ │
│  │             │    │              │    │         │ │
│  │  Customer   │    │   Spree      │    │  Spree  │ │
│  │  Browser   │◄──►│  Storefront   │◄──►│  Backend │ │
│  │             │    │ (Next.js)    │    │ (Rails)  │ │
│  └─────────────┘    └────────────────┘    └─────────┘ │
│         │                      │                      │         │
│         │                      │                      │         │
│         ▼                      ▼                      ▼         │
│  ┌──────────────────────────────────────────────────────┐         │
│  │           Microsoft Entra External ID              │         │
│  │              (B2C)                               │         │
│  │  ┌─────────────┐  ┌──────────────┐           │         │
│  │  │   Google    │  │   Facebook   │           │         │
│  │  │   Login    │  │   Login     │           │         │
│  │  └─────────────┘  └──────────────┘           │         │
│  │  ┌─────────────┐  ┌──────────────┐           │         │
│  │  │   Apple     │  │  Microsoft  │           │         │
│  │  │   ID       │  │   Login     │           │         │
│  │  └─────────────┘  └──────────────┘           │         │
│  └──────────────────────────────────────────────────────┘         │
│                                                     │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 ขั้นตอนการทำงาน (Authentication Flow)

### 1️⃣ **Social Login Initiation**
```
Customer คลิก "Login with Google" → 
Redirect ไป Entra B2C → 
Google OAuth Flow → 
Entra B2C สร้าง JWT Token → 
Redirect กลับ Storefront พร้อม Token
```

### 2️⃣ **Token Handling**
```
Storefront รับ JWT Token → 
Validate Token กับ Spree Backend → 
Create/Update Spree User Account → 
Set Spree Session → 
Login สำเร็จ
```

### 3️⃣ **Session Management**
```
Customer ใช้งาน → 
Spree JWT Token ใน Cookie → 
Auto-refresh Token → 
Seamless ประสบการณ์
```

## 🛠️ Technical Components

### **Frontend (Next.js Storefront)**
- **Auth.js** สำหรับ OAuth handling
- **Microsoft Entra ID Provider** configuration
- **Custom Auth Components** สำหรับ Social Login UI
- **Token Storage** ใน HttpOnly Cookies
- **Auth Middleware** สำหรับ route protection

### **Backend (Spree Rails)**
- **OAuth Validation Endpoint** สำหรับ token verification
- **User Synchronization** ระหว่า Entra ↔ Spree users
- **Session Management** ผ่าน Spree's existing system
- **API Integration** กับ Spree's authentication

### **Identity Provider (Microsoft Entra B2C)**
- **OAuth 2.0** สำหรับ authorization
- **Social Providers** (Google, Facebook, Apple, Microsoft)
- **JWT Tokens** สำหรับ user identity
- **User Attributes** สำหรับ profile synchronization

## 📋 Implementation Strategy

### **Phase 1: Core SSO Integration**
1. ติดตั้ง Auth.js ใน Spree Storefront
2. ตั้งค่า Microsoft Entra ID Provider
3. สร้าง OAuth validation ใน Spree Backend
4. ทดสอบ basic login flow

### **Phase 2: Social Login Expansion**
1. เพิ่ม Google, Facebook, Apple providers
2. สร้าง unified login UI
3. จัดการ user profile synchronization
4. ทดสอบ multi-provider login

### **Phase 3: Advanced Features**
1. Auto-provisioning สำหรับ existing users
2. Role-based access control
3. Multi-factor authentication (MFA)
4. Audit logging และ compliance

## 🔐 Security Considerations

### **Token Security**
- HttpOnly cookies สำหรับ JWT storage
- Short token expiration (1 hour)
- Secure refresh token mechanism
- CSRF protection สำหรับ state parameter

### **Data Privacy**
- Minimal data collection จาก social providers
- GDPR compliance สำหรับ EU users
- User consent management
- Data portability options

### **Integration Security**
- HTTPS enforcement ทุก connections
- Certificate pinning สำหรับ Entra endpoints
- Rate limiting สำหรับ auth attempts
- Audit trail สำหรับ all auth events

## 📊 Monitoring & Analytics

### **Authentication Metrics**
- Login success/failure rates
- Provider-specific usage statistics
- Session duration analytics
- Geographic access patterns

### **Performance Monitoring**
- Token validation latency
- Social provider response times
- User experience metrics
- Error rate tracking

## 🚀 Deployment Architecture

### **Development Environment**
```
Local Spree Backend (localhost:3000)
├── Entra B2C Development Tenant
├── Local Storefront (localhost:3001)
└── Cloudflare Tunnel สำหรับ HTTPS
```

### **Production Environment**
```
Production Spree Backend
├── Entra B2C Production Tenant
├── Production Storefront (Vercel/Netlify)
├── CDN สำหรับ static assets
└── Load Balancer สำหรับ high availability
```

## 📚 Dependencies & Libraries

### **Frontend Requirements**
```json
{
  "dependencies": {
    "next-auth": "^4.24.0",
    "@auth/entra-id": "^1.0.0",
    "jose": "^5.0.0",
    "axios": "^1.6.0"
  }
}
```

### **Backend Requirements**
```ruby
# Gemfile
gem 'jwt', '~> 2.7'
gem 'oauth2', '~> 2.0'
gem 'httparty', '~> 2.8'
```

## 🎯 Success Criteria

### **Functional Requirements**
- ✅ Customer สามารถ login ด้วย Google/Facebook/Apple/Microsoft
- ✅ Seamless integration กับ Spree's existing user system
- ✅ Auto-provisioning สำหรับ new users
- ✅ Session persistence ข้าม browser restarts

### **Non-Functional Requirements**
- ✅ Login time < 3 seconds
- ✅ 99.9% uptime สำหรับ auth service
- ✅ GDPR compliance สำหรับ data handling
- ✅ Mobile-responsive login UI

### **Business Requirements**
- ✅ Reduced cart abandonment rate
- ✅ Increased conversion rate
- ✅ Improved user experience
- ✅ Scalable สำหรับ traffic growth
