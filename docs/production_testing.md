# Production SSO Testing Guide

## 🧪 Complete Testing Checklist

### **1️⃣ Pre-Deployment Testing**

#### **Backend Testing**
```bash
# Test SSO endpoints locally
curl -X POST http://localhost:3000/api/sso/validate_token \
  -H "Content-Type: application/json" \
  -d '{"token": "test_jwt_token", "provider": "entra_id"}'

# Test user creation
curl -X POST http://localhost:3000/api/sso/create_user \
  -H "Content-Type: application/json" \
  -d '{
    "user_data": {
      "sub": "test_user_id",
      "email": "test@example.com",
      "first_name": "Test",
      "last_name": "User"
    },
    "provider": "entra_id"
  }'
```

#### **Frontend Testing**
```bash
# Test OAuth handler
curl -X POST http://localhost:3001/api/auth/[...nextauth] \
  -H "Content-Type: application/json" \
  -d '{"code": "test_code", "state": "test_state"}'

# Test health endpoints
curl http://localhost:3001/api/health
curl http://localhost:3001/api/sso/health
```

### **2️⃣ Production Environment Testing**

#### **Environment Variables Validation**
```bash
# Check backend environment
heroku config --app your-spree-backend

# Check frontend environment
vercel env ls
```

#### **Database Connection**
```bash
# Test database connection
heroku run rails db:migrate --app your-spree-backend
heroku run rails console --app your-spree-backend

# In Rails console
ActiveRecord::Base.connection.execute("SELECT 1")
```

#### **Redis Connection**
```bash
# Test Redis connection
heroku run rails runner "Redis.new.ping" --app your-spree-backend
```

### **3️⃣ End-to-End SSO Flow Testing**

#### **Test Case 1: Successful Login Flow**
```javascript
// Test script for browser console
const testSSOFlow = async () => {
  try {
    // 1. Test OAuth URL generation
    const authUrl = `https://login.microsoftonline.com/${process.env.NEXT_PUBLIC_ENTRA_TENANT_ID}/oauth2/v2.0/authorize?client_id=${process.env.NEXT_PUBLIC_ENTRA_CLIENT_ID}&response_type=code&redirect_uri=${encodeURIComponent(window.location.origin + '/api/auth/callback/entra-id')}&response_mode=query&scope=openid%20profile%20email%20offline_access&state=test_state`;
    
    console.log('Auth URL:', authUrl);
    
    // 2. Test token exchange (mock)
    const mockTokenResponse = {
      access_token: 'mock_access_token',
      refresh_token: 'mock_refresh_token',
      expires_in: 3600
    };
    
    // 3. Test user info retrieval
    const mockUserInfo = {
      id: 'test_user_id',
      displayName: 'Test User',
      mail: 'test@example.com',
      givenName: 'Test',
      surname: 'User'
    };
    
    // 4. Test Spree backend validation
    const spreeResponse = await fetch('/api/sso/validate_token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token: mockTokenResponse.access_token,
        provider: 'entra_id',
        user_data: {
          sub: mockUserInfo.id,
          email: mockUserInfo.mail,
          first_name: mockUserInfo.givenName,
          last_name: mockUserInfo.surname,
          name: mockUserInfo.displayName,
        }
      })
    });
    
    const spreeData = await spreeResponse.json();
    console.log('Spree Response:', spreeData);
    
    return spreeData.success;
  } catch (error) {
    console.error('SSO Flow Test Error:', error);
    return false;
  }
};

testSSOFlow();
```

#### **Test Case 2: Error Handling**
```javascript
// Test error scenarios
const testErrorScenarios = async () => {
  // Test invalid token
  const invalidTokenResponse = await fetch('/api/sso/validate_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: 'invalid_token', provider: 'entra_id' })
  });
  
  console.log('Invalid Token Response:', await invalidTokenResponse.json());
  
  // Test missing token
  const missingTokenResponse = await fetch('/api/sso/validate_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ provider: 'entra_id' })
  });
  
  console.log('Missing Token Response:', await missingTokenResponse.json());
  
  // Test invalid provider
  const invalidProviderResponse = await fetch('/api/sso/validate_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: 'some_token', provider: 'invalid_provider' })
  });
  
  console.log('Invalid Provider Response:', await invalidProviderResponse.json());
};

testErrorScenarios();
```

### **4️⃣ Performance Testing**

#### **Load Testing Script**
```bash
# Install artillery for load testing
npm install -g artillery

# Create artillery config
cat > artillery-config.yml << EOF
config:
  target: 'https://your-storefront-domain.com'
  phases:
    - duration: 60
      arrivalRate: 5
    - duration: 120
      arrivalRate: 10
    - duration: 60
      arrivalRate: 5

scenarios:
  - name: "SSO Login Flow"
    weight: 70
    flow:
      - get:
          url: "/api/health"
      - think: 2
      - get:
          url: "/api/sso/health"
  
  - name: "Product Browse"
    weight: 30
    flow:
      - get:
          url: "/products"
      - think: 3
EOF

# Run load test
artillery run artillery-config.yml
```

#### **Database Performance**
```sql
-- Monitor database performance during SSO operations
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements 
WHERE query LIKE '%sso%' OR query LIKE '%social_accounts%'
ORDER BY total_time DESC 
LIMIT 10;
```

### **5️⃣ Security Testing**

#### **CORS Testing**
```bash
# Test CORS headers
curl -H "Origin: https://your-storefront-domain.com" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     https://your-spree-backend.com/api/sso/validate_token
```

#### **Rate Limiting Test**
```bash
# Test rate limiting (if implemented)
for i in {1..15}; do
  curl -X POST https://your-spree-backend.com/api/sso/validate_token \
       -H "Content-Type: application/json" \
       -d '{"token": "test", "provider": "entra_id"}'
  echo "Request $i completed"
done
```

#### **Token Validation Test**
```bash
# Test JWT token validation
# 1. Create a test JWT token (use online JWT generator)
# 2. Test with expired token
# 3. Test with invalid signature
# 4. Test with malformed token
```

### **6️⃣ Integration Testing**

#### **Complete User Journey**
```javascript
// Automated integration test
const completeUserJourney = async () => {
  const browser = await puppeteer.launch({ headless: false });
  const page = await browser.newPage();
  
  try {
    // 1. Navigate to storefront
    await page.goto('https://your-storefront-domain.com');
    
    // 2. Click login button
    await page.click('[data-testid="login-button"]');
    
    // 3. Click Microsoft login
    await page.click('[data-testid="microsoft-login"]');
    
    // 4. Handle Microsoft login (manual for now)
    console.log('Please complete Microsoft login manually...');
    
    // 5. Wait for redirect back
    await page.waitForNavigation();
    
    // 6. Check if user is logged in
    const loggedInUser = await page.evaluate(() => {
      return window.localStorage.getItem('user');
    });
    
    console.log('Logged in user:', loggedInUser);
    
    // 7. Test user data persistence
    await page.reload();
    const persistedUser = await page.evaluate(() => {
      return window.localStorage.getItem('user');
    });
    
    console.log('Persisted user:', persistedUser);
    
    // 8. Test logout
    await page.click('[data-testid="logout-button"]');
    
    // 9. Verify logout
    const loggedOutUser = await page.evaluate(() => {
      return window.localStorage.getItem('user');
    });
    
    console.log('Logged out user:', loggedOutUser);
    
    await browser.close();
    return true;
  } catch (error) {
    console.error('Integration test error:', error);
    await browser.close();
    return false;
  }
};

completeUserJourney();
```

### **7️⃣ Monitoring & Alerting**

#### **Health Check Monitoring**
```bash
# Set up monitoring script
cat > monitor-sso.sh << EOF
#!/bin/bash

# Check backend health
BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" https://your-spree-backend.com/api/health)
if [ $BACKEND_HEALTH -ne 200 ]; then
  echo "❌ Backend health check failed: $BACKEND_HEALTH"
  # Send alert (Slack, email, etc.)
else
  echo "✅ Backend health check passed"
fi

# Check frontend health
FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" https://your-storefront-domain.com/api/health)
if [ $FRONTEND_HEALTH -ne 200 ]; then
  echo "❌ Frontend health check failed: $FRONTEND_HEALTH"
  # Send alert
else
  echo "✅ Frontend health check passed"
fi

# Check SSO configuration
SSO_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" https://your-storefront-domain.com/api/sso/health)
if [ $SSO_HEALTH -ne 200 ]; then
  echo "❌ SSO health check failed: $SSO_HEALTH"
  # Send alert
else
  echo "✅ SSO health check passed"
fi
EOF

chmod +x monitor-sso.sh
```

#### **Log Monitoring**
```bash
# Monitor Spree backend logs
heroku logs --tail --app your-spree-backend | grep "SSO\|OAuth\|Auth"

# Monitor Vercel logs
vercel logs --follow
```

### **8️⃣ Rollback Plan**

#### **Quick Rollback Commands**
```bash
# Rollback Spree backend
heroku rollback --app your-spree-backend

# Rollback Storefront (Vercel)
vercel rollback --preprod

# Database rollback (if needed)
heroku run rails db:rollback VERSION=20260508041438 --app your-spree-backend
```

#### **Rollback Testing**
```bash
# Test rollback functionality
# 1. Deploy a broken version
# 2. Verify rollback works
# 3. Test data integrity after rollback
```

## 📊 Test Results Template

### **Test Results Summary**
```
✅ Backend SSO endpoints: PASS
✅ Frontend OAuth handler: PASS
✅ Database connectivity: PASS
✅ Redis connectivity: PASS
✅ Environment variables: PASS
✅ CORS configuration: PASS
✅ Rate limiting: PASS (if implemented)
✅ JWT token validation: PASS
✅ User creation flow: PASS
✅ Error handling: PASS
⚠️ Performance under load: WARNING (response time > 2s)
✅ Security headers: PASS
✅ HTTPS enforcement: PASS
```

### **Performance Metrics**
```
Average response time: 1.2s
95th percentile: 2.1s
99th percentile: 3.5s
Error rate: 0.1%
Throughput: 50 req/s
```

### **Security Checklist**
```
✅ All endpoints use HTTPS
✅ CORS properly configured
✅ Rate limiting implemented
✅ Input validation present
✅ Error messages don't leak info
✅ Session management secure
✅ Token expiration enforced
✅ Proper logging without sensitive data
```

## 🚀 Go-Live Checklist

### **Final Checklist**
- [ ] All environment variables set
- [ ] Database migrations run
- [ ] SSL certificates valid
- [ ] Domain names configured
- [ ] DNS records updated
- [ ] Monitoring enabled
- [ ] Backup strategy in place
- [ ] Rollback plan tested
- [ ] Team trained on troubleshooting
- [ ] Documentation complete
- [ ] Support contact information available

### **Post-Launch Monitoring**
- [ ] Monitor error rates
- [ ] Monitor performance metrics
- [ ] Monitor user feedback
- [ ] Monitor security alerts
- [ ] Schedule regular health checks
- [ ] Plan capacity scaling
- [ ] Review logs regularly
