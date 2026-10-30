package com.somnicard.security;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Device-local encrypted credentials. Neither encryption key nor plaintext is exported. */
public final class SomnicardVault extends GodotPlugin {
    private static final String ALIAS = "com.somnicard.practice.credentials.v1";
    private static final byte[] AAD = ALIAS.getBytes(StandardCharsets.UTF_8);
    public SomnicardVault(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "SomnicardVault"; }
    private AtomicFile file() {
        return new AtomicFile(new File(getActivity().getNoBackupFilesDir(), "ai-credentials.v1"));
    }
    private SecretKey key(boolean create) throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        if (!store.containsAlias(ALIAS)) {
            if (!create) return null;
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build());
            return generator.generateKey();
        }
        return (SecretKey) store.getKey(ALIAS, null);
    }
    @UsedByGodot public synchronized boolean save(String text) {
        FileOutputStream output = null;
        AtomicFile target = null;
        try {
            target = file();
            byte[] input = text.getBytes(StandardCharsets.UTF_8);
            if (input.length > 65536) return false;
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key(true));
            cipher.updateAAD(AAD);
            byte[] encrypted = cipher.doFinal(input);
            output = target.startWrite();
            output.write(cipher.getIV()); // GCM uses a fresh 12-byte random IV for each save.
            output.write(encrypted);
            target.finishWrite(output);
            Arrays.fill(input, (byte) 0);
            return true;
        } catch (Exception ignored) {
            if (output != null) target.failWrite(output);
            return false;
        }
    }
    @UsedByGodot public synchronized String load() {
        try {
            AtomicFile target = file();
            if (!target.getBaseFile().exists() || target.getBaseFile().length() > 131072) return "";
            byte[] bytes = target.readFully();
            if (bytes.length < 28) return "";
            SecretKey secret = key(false);
            if (secret == null) return "";
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, secret, new GCMParameterSpec(128, bytes, 0, 12));
            cipher.updateAAD(AAD);
            return new String(cipher.doFinal(bytes, 12, bytes.length - 12), StandardCharsets.UTF_8);
        } catch (Exception ignored) { return ""; }
    }
    @UsedByGodot public synchronized boolean clear() {
        try {
            file().delete();
            KeyStore store = KeyStore.getInstance("AndroidKeyStore");
            store.load(null);
            if (store.containsAlias(ALIAS)) store.deleteEntry(ALIAS);
            return !file().getBaseFile().exists();
        } catch (Exception ignored) { return false; }
    }
}
