# Production Environment Setup Checklist

## 🔧 Environment Variables Configuration

### **Spree Backend (.env.production)**

#### **Required Variables**
- [ ] `DATABASE_URL` - PostgreSQL connection string
- [ ] `SECRET_KEY_BASE` - Rails secret key (generated)
- [ ] `RAILS_MASTER_KEY` - Rails master key (generated)
- [ ] `REDIS_URL` - Redis connection for Sidekiq
- [ ] `SPREE_PUBLISHABLE_KEY` - Spree API key

#### **SSO Configuration**
- [ ] `ENTRA_TENANT_ID` - Microsoft Entra ID tenant
- [ ] `ENTRA_CLIENT_ID` - Microsoft Entra ID client ID
- [ ] `ENTRA_CLIENT_SECRET` - Microsoft Entra ID client secret

#### **AI Configuration**
- [ ] `GEMINI_API_KEY` - Google Gemini API key

#### **Security Configuration**
- [ ] `RAILS_ENV=production`
- [ ] `RAILS_SERVE_STATIC_FILES=true`
- [ ] `RAILS_LOG_LEVEL=info`
- [ ] `RAILS_DEVELOPMENT_HOSTS` - Allowed domains

### **Storefront (.env.production)**

#### **API Configuration**
- [ ] `SPREE_API_URL` - Production Spree backend URL
- [ ] `SPREE_PUBLISHABLE_KEY` - Spree API key

#### **SSO Configuration**
- [ ] `ENTRA_TENANT_ID` - Microsoft Entra ID tenant
- [ ] `ENTRA_CLIENT_ID` - Microsoft Entra ID client ID
- [ ] `ENTRA_CLIENT_SECRET` - Microsoft Entra ID client secret
- [ ] `NEXT_PUBLIC_ENTRA_TENANT_ID` - Public tenant ID
- [ ] `NEXT_PUBLIC_ENTRA_CLIENT_ID` - Public client ID

#### **Next.js Configuration**
- [ ] `NEXTAUTH_URL` - Production domain URL
- [ ] `NEXTAUTH_SECRET` - Next.js auth secret (generated)

#### **Site Configuration**
- [ ] `NEXT_PUBLIC_SITE_URL` - Production domain
- [ ] `NEXT_PUBLIC_DEFAULT_COUNTRY=us`
- [ ] `NEXT_PUBLIC_DEFAULT_LOCALE=en`

#### **Security Configuration**
- [ ] `NEXTAUTH_TRUST_HOST=true`
- [ ] `NEXTAUTH_URL_INTERNAL` - Internal URL

## 🔐 Security Setup

### **Entra ID Configuration**
- [ ] Create production tenant
- [ ] Register production app
- [ ] Configure redirect URI: `https://your-domain.com/api/auth/callback/entra-id`
- [ ] Set API permissions:
  - [ ] `User.Read`
  - [ ] `email`
  - [ ] `profile`
- [ ] Grant admin consent
- [ ] Generate client secret
- [ ] Set app as multi-tenant (if needed)

### **Domain Configuration**
- [ ] Configure DNS records
- [ ] Setup SSL certificates
- [ ] Verify domain ownership
- [ ] Configure CDN (if using)

## 🚀 Deployment Preparation

### **Backend Deployment**
- [ ] Choose deployment platform (Heroku/DigitalOcean/AWS)
- [ ] Configure database
- [ ] Configure Redis
- [ ] Set up monitoring
- [ ] Configure backup strategy
- [ ] Test deployment pipeline

### **Frontend Deployment**
- [ ] Choose deployment platform (Vercel/Netlify/AWS)
- [ ] Configure build settings
- [ ] Set up environment variables
- [ ] Configure custom domain
- [ ] Setup SSL
- [ ] Configure analytics

## 🧪 Pre-Deployment Testing

### **Local Testing**
```bash
# Test backend with production variables
RAILS_ENV=production rails server -e production

# Test frontend with production variables
NODE_ENV=production npm run build
npm run start
```

### **Integration Testing**
- [ ] Test SSO flow end-to-end
- [ ] Test token validation
- [ ] Test user creation
- [ ] Test error handling
- [ ] Test CORS configuration
- [ ] Test rate limiting

### **Performance Testing**
- [ ] Load test SSO endpoints
- [ ] Test database performance
- [ ] Test Redis performance
- [ ] Test frontend performance
- [ ] Monitor memory usage

## 📊 Monitoring Setup

### **Health Checks**
- [ ] Backend health endpoint: `/api/health`
- [ ] Frontend health endpoint: `/api/health`
- [ ] SSO health endpoint: `/api/sso/health`
- [ ] Database connectivity check
- [ ] Redis connectivity check

### **Logging**
- [ ] Configure structured logging
- [ ] Set up log aggregation
- [ ] Configure error tracking (Sentry)
- [ ] Set up performance monitoring
- [ ] Configure alerting

### **Security Monitoring**
- [ ] Set up security scanning
- [ ] Configure intrusion detection
- [ ] Monitor failed login attempts
- [ ] Track token usage
- [ ] Monitor API abuse

## 🔄 Post-Deployment

### **Verification**
- [ ] Verify all services are running
- [ ] Test SSO login flow
- [ ] Test user registration
- [ ] Test logout functionality
- [ ] Verify SSL certificates
- [ ] Check domain configuration

### **Performance Monitoring**
- [ ] Monitor response times
- [ ] Track error rates
- [ ] Monitor resource usage
- [ ] Track user experience metrics
- [ ] Monitor SSO performance

### **Backup Verification**
- [ ] Verify database backups
- [ ] Test restore procedures
- [ ] Verify configuration backups
- [ ] Test disaster recovery

## 🚨 Rollback Plan

### **Quick Rollback**
- [ ] Document rollback procedures
- [ ] Test rollback process
- [ ] Prepare rollback scripts
- [ ] Set up monitoring for rollback

### **Data Integrity**
- [ ] Verify data consistency
- [ ] Check user data integrity
- [ ] Verify SSO account linkage
- [ ] Test data recovery procedures

## 📞 Support Documentation

### **Troubleshooting Guide**
- [ ] Document common issues
- [ ] Create troubleshooting steps
- [ ] Document error codes
- [ ] Provide contact information
- [ ] Create escalation procedures

### **Team Training**
- [ ] Train team on monitoring
- [ ] Document emergency procedures
- [ ] Create on-call schedule
- [ ] Provide access documentation
