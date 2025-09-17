-- Project configuration
set_project("rtty")
set_version("9.0.2")
set_languages("c99")

-- Build modes
add_rules("mode.debug", "mode.release")

-- Global compile options
add_cflags("-Wall", "-Werror", "-O")
add_defines("_GNU_SOURCE")

-- Include directories
add_includedirs("src", "src/buffer", "src/ssl")

-- Check dependencies
add_requires("libev")

-- Options for SSL support
option("ssl_support")
    set_default(true)
    set_showmenu(true)
    set_description("Enable SSL support")
option_end()

option("ssl_backend")
    set_default("auto")
    set_values("auto", "openssl", "wolfssl", "mbedtls")
    set_showmenu(true)
    set_description("SSL backend selection")
option_end()

-- Log static library
target("log")
    set_kind("static")
    add_files("src/log/log.c")
    add_cflags("-fPIC")
target_end()

-- SSL static library (conditional)
if has_config("ssl_support") then
    target("xssl")
        set_kind("static")
        add_cflags("-fPIC")
        add_includedirs("src/ssl")
        
        -- Add SSL source files based on configuration
        local ssl_backend = get_config("ssl_backend") 
        if ssl_backend == "openssl" then
            add_files("src/ssl/openssl.c")
            add_packages("openssl")
            add_defines("HAVE_OPENSSL")
        elseif ssl_backend == "mbedtls" then
            add_files("src/ssl/mbedtls.c")
            add_packages("mbedtls")
            add_defines("HAVE_MBEDTLS")
        else -- auto or fallback to openssl
            add_files("src/ssl/openssl.c")
            add_packages("openssl")
            add_defines("HAVE_OPENSSL")
        end
    target_end()
end

-- Main executable
target("rtty")
    set_kind("binary")
    add_deps("log")
    
    -- Add SSL dependency conditionally
    if has_config("ssl_support") then
        add_deps("xssl")
    end
    
    -- Main source files
    add_files("src/*.c")
    add_files("src/buffer/*.c")
    
    -- Exclude ssl and log directories (handled separately)
    remove_files("src/ssl/*.c")
    remove_files("src/log/*.c")
    
    -- System libraries
    add_syslinks("util", "crypt", "m")
    add_packages("libev")
    
    -- SSL packages and system libraries
    if has_config("ssl_support") then
        local ssl_backend = get_config("ssl_backend")
        if ssl_backend == "openssl" then
            add_packages("openssl")
            add_syslinks("ssl", "crypto")
        elseif ssl_backend == "mbedtls" then
            add_packages("mbedtls")
        else -- auto or fallback to openssl
            add_packages("openssl")
            add_syslinks("ssl", "crypto")
        end
    end
    
    -- Generate config header before compilation
    before_build(function (target)
        local configheader = path.join(target:targetdir(), "config.h")
        local ssl_define = has_config("ssl_support") and "#define SSL_SUPPORT\n" or ""
        local content = [[/*
 * MIT License
 *
 * Copyright (c) 2019 Jianhui Zhao <zhaojh329@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef _RTTY_CONFIG_H
#define _RTTY_CONFIG_H

#define RTTY_VERSION_MAJOR  9
#define RTTY_VERSION_MINOR  0
#define RTTY_VERSION_PATCH  2
#define RTTY_VERSION_STRING "9.0.2"

]] .. ssl_define .. [[

#endif
]]
        io.writefile(configheader, content)
        target:add("includedirs", target:targetdir())
    end)
target_end()
