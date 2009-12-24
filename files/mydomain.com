server {

            listen   80;
            server_name  www.mydomain.com;
            rewrite ^/(.*) http://mydomain.com/$1 permanent;

           }


server {

            listen   80;
            server_name mydomain.com;

            access_log /home/public_html/mydomain.com/log/access.log;
            error_log /home/public_html/mydomain.com/log/error.log;

            location / {

                        root   /home/public_html/mydomain.com/public/;
                        index  index.php index.html;

                        # Basic version of Wordpress parameters, supporting nice permalinks.
                        include /etc/nginx/conf/wp.conf;
                        # Advanced version of Wordpress parameters supporting nice permalinks and WP Super Cache plugin
                        include /etc/nginx/conf/wp_super_cache.conf;
                        }

            # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
            #
            location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            include /etc/nginx/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME /home/public_html/mydomain.com/public/$fastcgi_script_name;
            }
      }
