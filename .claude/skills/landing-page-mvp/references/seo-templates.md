# SEO & Meta Templates

> Auto-generated during scaffold from brand name, purpose, and value props.
> Generated UPSTREAM (in index.html) during project creation, not as an afterthought.

## HTML Head Template

```html
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{{brand_name}} — {{brand_purpose}}</title>
  <meta name="description" content="{{brand_purpose}}. {{value_prop_1}}." />

  <!-- Open Graph -->
  <meta property="og:type" content="website" />
  <meta property="og:title" content="{{brand_name}} — {{brand_purpose}}" />
  <meta property="og:description" content="{{brand_purpose}}. {{value_prop_1}}." />
  <meta property="og:image" content="https://picsum.photos/seed/{{brand_slug}}/1200/630" />
  <meta property="og:url" content="{{site_url}}" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="{{brand_name}}" />
  <meta name="twitter:description" content="{{brand_purpose}}" />

  <!-- Performance Hints -->
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link rel="preload" as="style" href="{{google_fonts_url}}" />

  <!-- Favicon -->
  <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
</head>
```

## JSON-LD Templates

### Organization (default for agencies/companies)
```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "{{brand_name}}",
  "description": "{{brand_purpose}}",
  "url": "{{site_url}}"
}
```

### Product (for SaaS/tools)
```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "{{brand_name}}",
  "description": "{{brand_purpose}}",
  "brand": { "@type": "Brand", "name": "{{brand_name}}" }
}
```

### LocalBusiness (for physical businesses)
```json
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "{{brand_name}}",
  "description": "{{brand_purpose}}"
}
```

## robots.txt

```
User-agent: *
Allow: /
Sitemap: {{site_url}}/sitemap.xml
```

## Selection Logic

Infer JSON-LD type from brand purpose keywords:
- "SaaS", "platform", "tool", "app", "software" -> Product
- "restaurant", "bakery", "shop", "store", "clinic" -> LocalBusiness
- Default -> Organization
