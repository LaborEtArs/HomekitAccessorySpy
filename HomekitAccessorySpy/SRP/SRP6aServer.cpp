/*
 * SRP6aServer.cpp
 */
#include "../SRP/SRP6aServer.h"

#include <cstring>
#include <stdio.h>

#define lea_serial_printf	printf

/*
 * SRP6aServer Constructor
 */
clsSRP6aServer::clsSRP6aServer(void)
:	m_pucUsername(0),
	m_iUsernameLength(0),
	m_pucSalt(0),
	m_iSaltLength(0),
	m_bRSuccessfullyCreated(false) {

	mpz_init(m_bnModulus);
	mpz_init(m_bnGenerator);
	mpz_init(m_bnVerifier);
	mpz_init(m_bnPassword);
	mpz_init(m_bnPublicKey);
	mpz_init(m_bnSecretKey);
	mpz_init(m_bnU);
	mpz_init(m_bnKey);

	m_shaHash.clear();
	m_shaCKHash.clear();
	m_shaOldHash.clear();
	m_shaOldCKHash.clear();
}

/*
 * SRP6aServer Destructor
 *
 */
clsSRP6aServer::~clsSRP6aServer(void) {

	if (m_pucUsername) {
		delete[] m_pucUsername;
		m_pucUsername = 0;
		m_iUsernameLength = 0;
	}
	if (m_pucSalt) {
		delete[] m_pucSalt;
		m_pucSalt = 0;
		m_iSaltLength = 0;
	}
	mpz_clear(m_bnModulus);
	mpz_clear(m_bnGenerator);
	mpz_clear(m_bnVerifier);
	mpz_clear(m_bnPassword);
	mpz_clear(m_bnPublicKey);
	mpz_clear(m_bnSecretKey);
	mpz_clear(m_bnU);
	mpz_clear(m_bnKey);
}

/*
 * SRP6aServer::set_username
 *
 */
int clsSRP6aServer::set_username(const char* p_pcUsername) {

	if (m_pucUsername) {
		delete[] m_pucUsername;
		m_pucUsername = 0;
		m_iUsernameLength = 0;
	}
	m_iUsernameLength = (int)strlen(p_pcUsername);
	if (m_iUsernameLength) {
		m_pucUsername = new unsigned char[m_iUsernameLength];
		memcpy(m_pucUsername, p_pcUsername, m_iUsernameLength);
	}
	return SRP_SUCCESS;
}

/*
 * SRP6aServer::set_params
 *
 */
int clsSRP6aServer::set_params(const unsigned char* p_pucModulus, int p_iModulusLength,
		const unsigned char* p_pucGenerator, int p_iGeneratorLength,
		const unsigned char* p_pucSalt, int p_iSaltLength) {

	if ((p_pucModulus) &&
		(p_iModulusLength) &&
		(p_pucGenerator) &&
		(p_iGeneratorLength) &&
		(p_pucSalt) &&
		(p_iSaltLength)) {

		//mpz_import(m_bnModulus, p_iModulusLength, 1, sizeof(p_pucModulus[0]), 0, 0, p_pucModulus);
		mpz_import(m_bnModulus, p_iModulusLength, 1, 1, 1, 0, p_pucModulus);
		mpz_import(m_bnGenerator, p_iGeneratorLength, 1, 1, 1, 0, p_pucGenerator);

		if (m_pucSalt) {
			delete[] m_pucSalt;
		}
		m_pucSalt = new unsigned char[p_iSaltLength];
		memcpy(m_pucSalt, p_pucSalt, (m_iSaltLength = p_iSaltLength));
		//print("pSalt:", p_pucSalt, p_iSaltLength);
		//print("mSalt:", m_pucSalt, m_iSaltLength);

		if (3072 == mpz_sizeinbase(m_bnModulus, 2)) {
			unsigned char	buf1[SHA512_DIGESTSIZE];
			unsigned char	buf2[SHA512_DIGESTSIZE];

			SHA512	sha512;

			sha512.clear();
			sha512.update(p_pucModulus, p_iModulusLength);
			sha512.finalize(buf1, sizeof(buf1));						// buf1 = H(modulus N)

			sha512.clear();
			sha512.update(p_pucGenerator, p_iGeneratorLength);
			sha512.finalize(buf2, sizeof(buf2));						// buf1 = H(generator g)

			for(unsigned i = 0; i < sizeof(buf1); ++i) {
			    buf1[i] ^= buf2[i];										// buf1 = H(modulus N) XOR H(generator g)
			}

			m_shaCKHash.update(buf1, sizeof(buf1));						// ckhash: H(modulus N) xor H(generator g)

			sha512.clear();
			sha512.update(m_pucUsername, m_iUsernameLength);
			sha512.finalize(buf1, sizeof(buf1));						// buf1 = H(Username)

			m_shaCKHash.update(buf1, sizeof(buf1));						// ckhash: (H(modulus N) xor H(generator g)) | H(Username)
			m_shaCKHash.update(p_pucSalt, p_iSaltLength);				// ckhash: (H(modulus N) xor H(generator g)) | H(Username) | salt

			return SRP_SUCCESS;
		}
		else {
			lea_serial_printf("Invalid modulus size!\n");
		}
	}
	else {
		lea_serial_printf("Invalid parameters!\n");
	}
	return SRP_ERROR;
}

/*
 * SRP6aServer::set_authenticator
 *
 */
int clsSRP6aServer::set_authenticator(const unsigned char* p_pucAuthenticator, int p_iAuthenticatorLength) {

	if ((p_pucAuthenticator) &&
		(p_iAuthenticatorLength)) {

		mpz_import(m_bnVerifier, p_iAuthenticatorLength, 1, 1, 1, 0, p_pucAuthenticator);
		return SRP_SUCCESS;
	}
	return SRP_ERROR;
}

/*
 * SRP6aServer::set_auth_password
 *
 */
int clsSRP6aServer::set_auth_password(const char* p_pcPassword) {
//lea_serial_printf("set_auth_password(%s)\n", p_pcPassword);
	if ((p_pcPassword) &&
		(*p_pcPassword)) {

		unsigned char	dig[SHA512_DIGESTSIZE];
		SHA512	sha512;

		sha512.clear();
		sha512.update(m_pucUsername, m_iUsernameLength);
		//print("Username:", m_pucUsername, m_iUsernameLength);
		sha512.update((const unsigned char*)":", 1);
		sha512.update((const unsigned char*)p_pcPassword, strlen(p_pcPassword));
		//print("Password:", p_pcPassword);
		sha512.finalize(dig, sizeof(dig));
		//print("H(Username | ':' | Password)", dig, sizeof(dig));

		sha512.clear();
		sha512.update(m_pucSalt, m_iSaltLength);
		//print("Salt:", m_pucSalt, m_iSaltLength);

		sha512.update(dig, sizeof(dig));
		sha512.finalize(dig, sizeof(dig));
		//print("H(salt | H(Username | ':' | Password))", dig, sizeof(dig));
		sha512.clear();

		mpz_import(m_bnPassword, sizeof(dig), 1, 1, 1, 0, dig);
		memset(dig, 0, sizeof(dig));
		//print("Private key (x):", m_bnPassword);

		mpz_init(m_bnVerifier);
		mpz_powm(m_bnVerifier, m_bnGenerator, m_bnPassword, m_bnModulus);
		print("Verifier (v):", m_bnVerifier);

		return SRP_SUCCESS;
	}
	return SRP_ERROR;
}

const unsigned char b[] = {	// should be random ;-)
		0xE4, 0x87, 0xCB, 0x59, 0xD3, 0x1A, 0xC5, 0x50,
		0x47, 0x1E, 0x81, 0xF0, 0x0F, 0x69, 0x28, 0xE0,
		0x1D, 0xDA, 0x08, 0xE9, 0x74, 0xA0, 0x04, 0xF4,
		0x9E, 0x61, 0xF5, 0xD1, 0x05, 0x28, 0x4D, 0x20
};
/*
 * SRP6aServer::gen_pub
 *
 */
int clsSRP6aServer::gen_pub(unsigned char** p_pucResult) {

	SHA512			sha512;
	unsigned char	dig[SHA512_DIGESTSIZE];

	sha512.clear();
	int				bufSize = (int)(mpz_sizeinbase(m_bnModulus, 2) + 7) / 8;	// in byte
	unsigned char*	aucS = new unsigned char[bufSize];
	size_t			count;
	mpz_export((void*)aucS, &count, 1, 1, 1, 0, m_bnModulus);
	//lea_serial_printf("gen_pub, bufSize:%u, count:%u\n", bufSize, count);
	//print("modulus:", aucS, count);
	sha512.update(aucS, count);
	mpz_export((void*)aucS, &count, 1, 1, 1, 0, m_bnGenerator);
	if ((int)count < bufSize) {
		// left padding needed
		memmove(aucS + (bufSize - count), aucS, count);
		memset(aucS, 0, (bufSize - count));
	}
	//print("generator:", aucS, bufSize);
	sha512.update(aucS, bufSize);
	sha512.finalize(dig, sizeof(dig));
	//print("gen_pub dig:", dig, sizeof(dig));
	delete[] aucS;

	mpz_t	bnK;
	mpz_init(bnK);
	mpz_import(bnK, sizeof(dig), 1, 1, 1, 0, dig);
	//print("K:", bnK);

	int	secretKeyBufSize = 32;
	(*p_pucResult) = new unsigned char[bufSize];
	for (int i=0; i<secretKeyBufSize; ++i) {
		(*p_pucResult)[i] = b[i];
	}
	mpz_import(m_bnSecretKey, secretKeyBufSize, 1, 1, 1, 0, (*p_pucResult));
	//print("Secret key (b):", m_bnSecretKey);

	//lea_ESP_wdtFeed();

	// B = kv + g^b mod n (blinding)
	mpz_mul(m_bnPublicKey, bnK, m_bnVerifier);
	mpz_powm(bnK, m_bnGenerator, m_bnSecretKey, m_bnModulus);
	mpz_add(bnK, bnK, m_bnPublicKey);
	mpz_mod(m_bnPublicKey, bnK, m_bnModulus);
	//print("Public key (B):", m_bnPublicKey);
	mpz_clear(bnK);

	mpz_export((void*)(*p_pucResult), &count, 1, 1, 1, 0, m_bnPublicKey);
	m_shaOldCKHash.update((*p_pucResult), count);

	return SRP_SUCCESS;
}

/*
 * SRP6aServer::compute_key
 *
 */
int clsSRP6aServer::compute_key(unsigned char** p_pucResult,
		const unsigned char* p_pucPublicKey, int p_iPublicKeyLength) {

	int				modulusLength = (int)(mpz_sizeinbase(m_bnModulus, 2) + 7) / 8;	// in byte
	if (p_iPublicKeyLength <= modulusLength) {
		// ckhash: (H(modulus N) xor H(generator g)) | H(Username) | salt | client public key A
		m_shaCKHash.update(p_pucPublicKey, p_iPublicKeyLength);

		// ckhash: (H(modulus N) xor H(generator g)) | H(Username) | salt | client public key A | server public key B
		unsigned char*	aucS = new unsigned char[modulusLength];
		size_t			count;
		mpz_export((void*)aucS, &count, 1, 1, 1, 0, m_bnPublicKey);
		m_shaCKHash.update(aucS, count);

		// hash: A
		m_shaHash.update(p_pucPublicKey, p_iPublicKeyLength);

		// oldhash: A
		m_shaOldHash.update(p_pucPublicKey, p_iPublicKeyLength);

		// Compute u = H(client public key A | server public key B)
		SHA512	sha512;
		sha512.clear();
		if (p_iPublicKeyLength < modulusLength) {
			lea_serial_printf("(p_iPublicKeyLength < modulusLength)");

			// H client public key A (left padded with 0)
			memcpy(aucS + (modulusLength - p_iPublicKeyLength), p_pucPublicKey, p_iPublicKeyLength);
			memset(aucS, 0, (modulusLength - p_iPublicKeyLength));
			sha512.update(aucS, modulusLength);

			// prepare server public key B (left padded with 0)
			mpz_export((void*)aucS, &count, 1, 1, 1, 0, m_bnPublicKey);
			memmove(aucS + (modulusLength - count), aucS, count);
			memset(aucS, 0, (modulusLength - count));
		}
		else {
			// H client public key A
			sha512.update(p_pucPublicKey, p_iPublicKeyLength);
			if ((int)count < modulusLength) {
				lea_serial_printf("((int)count < modulusLength)");

				// prepare server public key B (left padded with 0)
				mpz_export((void*)aucS, &count, 1, 1, 1, 0, m_bnPublicKey);
				memmove(aucS + (modulusLength - count), aucS, count);
				memset(aucS, 0, (modulusLength - count));
			}
		}
		// H server public key B
		unsigned char	dig[SHA512_DIGESTSIZE];
		sha512.update(aucS, modulusLength);
		// dig = H(A || B)
		sha512.finalize(dig, sizeof(dig));
		mpz_import(m_bnU, SHA512_DIGESTSIZE, 1, 1, 1, 0, dig);
		//print("m_bnU:", m_bnU);

		// compute A*v^u
		mpz_t	bnT1;
		mpz_init(bnT1);
		mpz_powm(bnT1, m_bnVerifier, m_bnU, m_bnModulus);	// T1 = v^u
		//print("bnT1:", bnT1);

		mpz_t	bnT2;
		mpz_init(bnT2);
		mpz_import(bnT2, p_iPublicKeyLength, 1, 1, 1, 0, p_pucPublicKey);	// T2 = A
		//print("bnT2:", bnT2);

		mpz_t	bnT3;
		mpz_init(bnT3);
		mpz_mul(bnT3, bnT2, bnT1);
		mpz_mod(bnT3, bnT3, m_bnModulus);
		mpz_clear(bnT2);
		//print("bnT3:", bnT3);

		if (0 < mpz_cmp_ui(bnT3, 1)) {
			mpz_add_ui(bnT1, bnT3, 1);
			if (0 != mpz_cmp(bnT1, m_bnModulus)) {
				mpz_powm(m_bnKey, bnT3, m_bnSecretKey, m_bnModulus);
				mpz_clear(bnT1);
				mpz_clear(bnT3);
				//print("Premaster Secret S:", m_bnKey);

				// convert m_bnKey into session key, update hashes
				memset(aucS, 0, modulusLength);
				mpz_export((void*)aucS, &count, 1, 1, 1, 0, m_bnKey);
				sha512.clear();
				sha512.update(aucS, count);
				sha512.finalize(m_aucK, sizeof(m_aucK));
				delete[] aucS;

				// ckhash: (H(N) xor H(g)) | H(U) | s | A | B | K
				m_shaCKHash.update(m_aucK, SHA512_DIGESTSIZE);
				// oldhash: A | K
				m_shaOldHash.update(m_aucK, SHA512_DIGESTSIZE);
				// oldckhash: B | K
				m_shaOldCKHash.update(m_aucK, SHA512_DIGESTSIZE);

				if (p_pucResult) {
					*p_pucResult = new unsigned char[SHA512_DIGESTSIZE];
					memcpy(*p_pucResult, m_aucK, SHA512_DIGESTSIZE);
					//print("Shared Secret K:", *p_pucResult, SHA512_DIGESTSIZE);
				}
				return SRP_SUCCESS;
			}
			else {
				lea_serial_printf("Reject A*v^u == -1 (mod N)");
				// Reject A*v^u == -1 (mod N)
				mpz_clear(bnT1);
				mpz_clear(bnT3);
				delete[] aucS;
				// -> error
			}
		}
		else {
			lea_serial_printf("Reject A*v^u == 0,1 (mod N)");
			// Reject A*v^u == 0,1 (mod N)
			mpz_clear(bnT1);
			mpz_clear(bnT3);
			delete[] aucS;
			// -> error
		}
	}
	return SRP_ERROR;
}

/*
 * SRP6aServer::verify
 *
 */
int clsSRP6aServer::verify(const unsigned char* p_pucProof, int p_iProofLength) {

	int				result = SRP_ERROR;

	unsigned char	expectedDig[SHA512_DIGESTSIZE];
	m_shaOldCKHash.finalize(expectedDig, sizeof(expectedDig));

	if ((SHA512_DIGESTSIZE == p_iProofLength) &&
		(0 == memcmp(p_pucProof, expectedDig, SHA512_DIGESTSIZE))) {

		m_shaOldHash.finalize(m_aucR, sizeof(m_aucR));
		//print("R(a):", m_aucR, sizeof(m_aucR));

		m_bRSuccessfullyCreated = true;
		result = SRP_SUCCESS;
	}
	else {
		m_shaCKHash.finalize(expectedDig, sizeof(expectedDig));
		if ((SHA512_DIGESTSIZE == p_iProofLength) &&
			(0 == memcmp(p_pucProof, expectedDig, SHA512_DIGESTSIZE))) {
			
			m_shaHash.update(expectedDig, sizeof(expectedDig));
			m_shaHash.update(m_aucK, sizeof(m_aucK));
			m_shaHash.finalize(m_aucR, sizeof(m_aucR));
			//print("R(b):", m_aucR, sizeof(m_aucR));
			
			m_bRSuccessfullyCreated = true;
			result = SRP_SUCCESS;
		}
	}
	return result;
}

/*
 * SRP6aServer::respond
 *
 */
int clsSRP6aServer::respond(unsigned char** p_pucResponse) {

	int		result = SRP_ERROR;
	
	if ((0 != p_pucResponse) &&
		(m_bRSuccessfullyCreated)) {
		
		*p_pucResponse = new unsigned char[SHA512_DIGESTSIZE];
		memcpy(*p_pucResponse, m_aucR, SHA512_DIGESTSIZE);

		result = SRP_SUCCESS;
	}
	return result;
}


// HELPERS

/*
 * print(BN)
 *
 */
void clsSRP6aServer::print(const char* p_pcComment,
		mpz_t p_bnValue) {

	int				bufSize = (int)(mpz_sizeinbase(p_bnValue, 2) + 7) / 8;
	unsigned char*	aucB = new unsigned char[bufSize];
	size_t			count;
	mpz_export((void*)aucB, &count, 1, 1, 1, 0, p_bnValue);

	print(p_pcComment, aucB, (unsigned)count);
	delete[] aucB;
}

/*
 * print(unsigned char*)
 *
 */
void clsSRP6aServer::print(const char* p_pcComment,
		const unsigned char* p_pucArray, int p_iLength) {

	lea_serial_printf("%s\n", p_pcComment);
	for (int j = 1; j <= p_iLength; ++j) {
		//Serial.write (array[j]);//Serial.write() transmits the ASCII numbers as human readable characters to serial monitor
		char s[3];
		sprintf(s, "0x%02x, ", p_pucArray[j - 1]);
		lea_serial_printf("%s", s);
		if (!(j % 16)) {
			lea_serial_printf("\n");
		}
	}
	lea_serial_printf("\n");
}

/*
 * print(char*)
 *
 */
void clsSRP6aServer::print(const char* p_pcComment,
		const char* p_pcString) {

	lea_serial_printf("%s\n", p_pcComment);
	for (unsigned j = 1; j <= strlen(p_pcString); ++j) {
		//Serial.write (array[j]);//Serial.write() transmits the ASCII numbers as human readable characters to serial monitor
		char s[2];
		sprintf(s, "%c", p_pcString[j - 1]);
		lea_serial_printf("%s", s);
		if (!(j % 64)) {
			lea_serial_printf("\n");
		}
	}
	lea_serial_printf("\n");
}




