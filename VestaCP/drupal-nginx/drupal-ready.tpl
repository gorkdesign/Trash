server {
    listen      %ip%:%web_port%;
    server_name %domain_idn% %alias_idn%;
    root        %docroot%;
    index       index.php index.html index.htm;
    access_log  /var/log/nginx/domains/%domain%.log combined;
    access_log  /var/log/nginx/domains/%domain%.bytes bytes;
    error_log   /var/log/nginx/domains/%domain%.error.log error;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location = /humans.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
        return 403;
    }

    location / {
        # try_files $uri @rewrite; # For Drupal <= 6
        try_files $uri /index.php?$query_string; # For Drupal >= 7

        ## Replicate the Apache <FilesMatch> directive of Drupal standard
        ## .htaccess. Disable access to any code files. Return a 404 to curtail
        ## information disclosure. Hide also the text files.
        location ~* ^(?:.+\.(?:htaccess|make|txt|engine|inc|info|install|module|profile|po|pot|sh|.*sql|test|theme|tpl(?:\.php)?|xtmpl)|code-style\.pl|/Entries.*|/Repository|/Root|/Tag|/Template)$ {
            return 404;
        }

        # Very rarely should these ever be accessed outside of your lan
        location ~* \.(txt|log)$ {
            allow 192.168.0.0/16;
            deny all;
        }

        ## Trying to access private files directly returns a 404.
        location ^~ /sites/default/files/private/ {
            internal;
        }

        # Don't allow direct access to PHP files in the vendor directory.
        location ~ /vendor/.*\.php$ {
            deny all;
            return 404;
        }

        # Fighting with Styles? This little gem is amazing.
        # location ~ ^/sites/.*/files/imagecache/ { # For Drupal <= 6
        location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
            try_files $uri @rewrite;
        }

        # Handle private files through Drupal.
        location ~ ^/system/files/ { # For Drupal >= 7
            try_files $uri /index.php?$query_string;
        }

        ##Add headers to advagg
        location ~* files/advagg_(?:css|js)/ {
            access_log off;
            expires    max;
            add_header ETag "";
            add_header Cache-Control "max-age=290304000, no-transform, public";
            add_header Last-Modified "Wed, 20 Jan 1988 04:20:42 GMT";
            try_files  $uri @drupal;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
            expires max;
            log_not_found off;
        }

        ## All static files will be served directly.
        location ~* ^.+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff2?|svg)$ {

            access_log off;
            expires 30d;
            ## No need to bleed constant updates. Send the all shebang in one
            ## fell swoop.
            tcp_nodelay off;
            ## Set the OS file cache.
            open_file_cache max=3000 inactive=120s;
            open_file_cache_valid 45s;
            open_file_cache_min_uses 2;
            open_file_cache_errors off;
        }

        # Vesta Config for factcgi. Didn't working without it.
        location ~ [^/]\.php(/|$) {
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            if (!-f $document_root$fastcgi_script_name) {
                return  404;
            }

            fastcgi_pass    %backend_lsnr%;
            fastcgi_index   index.php;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_intercept_errors on;
            include         /etc/nginx/fastcgi_params;
        }
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    error_page  403 /error/403.html;
    error_page  404 /error/404.html;
    error_page  500 502 503 504 /error/50x.html;

    location /error/ {
        alias   %home%/%user%/web/%domain%/document_errors/;
    }

    location ~* "/\.(htaccess|htpasswd)$" {
        deny    all;
        return  404;
    }

    include     /etc/nginx/conf.d/phpmyadmin.inc*;
    include     /etc/nginx/conf.d/phppgadmin.inc*;
    include     /etc/nginx/conf.d/webmail.inc*;

    include     %home%/%user%/conf/web/nginx.%domain%.conf*;
}