/*
 * SRP6aClient.cpp
 */
#include "../SRP/SRP6aClient.h"

#include <cstring>
#include <stdio.h>

#define lea_serial_printf	printf

/*
 * SRP6aClient Constructor
 */
clsSRP6aClient::clsSRP6aClient(void)
:	m_pucUsername(0),
	m_iUsernameLength(0),
	m_pucSalt(0),
	m_iSaltLength(0),
	m_bResonseSuccessfullyCreated(false) {

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
	//m_shaOldHash.clear();
	//m_shaOldCKHash.clear();
}

/*
 * SRP6aClient Destructor
 *
 */
clsSRP6aClient::~clsSRP6aClient(void) {

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
 * SRP6aClient::set_username
 *
 */
int clsSRP6aClient::set_username(const char* p_pcUsername) {

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
 * SRP6aClient::set_params
 *
 */
int clsSRP6aClient::set_params(const unsigned char* p_pucModulus, int p_iModulusLength,
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
			
			m_shaHash.update(buf1, sizeof(buf1));						// hash: H(modulus N) xor H(generator g)
			
			sha512.clear();
			sha512.update(m_pucUsername, m_iUsernameLength);
			sha512.finalize(buf1, sizeof(buf1));						// buf1 = H(Username)
			
			m_shaHash.update(buf1, sizeof(buf1));						// hash: (H(modulus N) xor H(generator g)) | H(Username)
			m_shaHash.update(p_pucSalt, p_iSaltLength);					// hash: (H(modulus N) xor H(generator g)) | H(Username) | salt
			
			return SRP_SUCCESS;
		}
		else {
			printf("Invalid modulus size!\n");
		}
	}
	else {
		printf("Invalid parameters!\n");
	}
	return SRP_ERROR;
}

/*
 * SRP6aClient::set_authenticator
 *
 */
int clsSRP6aClient::set_authenticator(const unsigned char* p_pucAuthenticator, int p_iAuthenticatorLength) {

	int	result = SRP_ERROR;
	
	if ((p_pucAuthenticator) &&
		(p_iAuthenticatorLength)) {
		
		// x = H(salt | H(Username | ':' | Password))
		mpz_import(m_bnPassword, p_iAuthenticatorLength, 1, 1, 1, 0, p_pucAuthenticator);

		// verifier = g^x mod N
		mpz_init(m_bnVerifier);
		mpz_powm(m_bnVerifier, m_bnGenerator, m_bnPassword, m_bnModulus);
		
		//print("Verifier:", m_bnVerifier);

		result = SRP_SUCCESS;
	}
	return result;
}

/*
 * SRP6aClient::set_auth_password
 *
 */
int clsSRP6aClient::set_auth_password(const char* p_pcPassword) {
//lea_serial_printf("set_auth_password(%s)\n", p_pcPassword);
	int	result = SRP_ERROR;
	
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

		result = set_authenticator(dig, sizeof(dig));
		memset(dig, 0, sizeof(dig));
	}
	return result;
}

static const unsigned char a[] = {	// should be random ;-)
	0x60, 0x97, 0x55, 0x27, 0x03, 0x5C, 0xF2, 0xAD,
	0x19, 0x89, 0x80, 0x6F, 0x04, 0x07, 0x21, 0x0B,
	0xC8, 0x1E, 0xDC, 0x04, 0xE2, 0x76, 0x2A, 0x56,
	0xAF, 0xD5, 0x29, 0xDD, 0xDA, 0x2D, 0x43, 0x93
};
/*
 * SRP6aClient::gen_pub
 *
 */
int clsSRP6aClient::gen_pub(unsigned char** p_pucResult) {

	unsigned char	aucSecretKey[32];
	for (int i=0; i<sizeof(aucSecretKey); ++i) {
		aucSecretKey[i] = a[i];
	}
	mpz_import(m_bnSecretKey, sizeof(aucSecretKey), 1, 1, 1, 0, aucSecretKey);
	//print("Secret key (b):", m_bnSecretKey);
	
	// Force g^a mod n to "wrap around" by adding log[2](n) to "a".
	// Fails, if done....
	//mpz_add_ui(m_bnSecretKey, m_bnSecretKey, mpz_sizeinbase(m_bnModulus, 2));

	mpz_init(m_bnPublicKey);
	mpz_powm(m_bnPublicKey, m_bnGenerator, m_bnSecretKey, m_bnModulus);

	int	bufSize = (int)(mpz_sizeinbase(m_bnModulus, 2) + 7) / 8;	// in byte
	(*p_pucResult) = new unsigned char[bufSize];
	
	size_t			count;
	mpz_export((void*)(*p_pucResult), &count, 1, 1, 1, 0, m_bnPublicKey);
	// hash: (H(N) xor H(g)) | H(U) | s | A
	m_shaHash.update((*p_pucResult), count);
	// ckhash: A
	m_shaCKHash.update((*p_pucResult), count);
	
	/*print("Secret Key:", m_bnSecretKey);
	print("Public Key:", m_bnPublicKey);
	unsigned char	tst[SHA512_DIGESTSIZE];
	m_shaHash.finalize(tst, sizeof(tst));
	print("shaHash:", tst, sizeof(tst));
	m_shaCKHash.finalize(tst, sizeof(tst));
	print("shaCKHash:", tst, sizeof(tst));*/

	return SRP_SUCCESS;
}

/*
 * SRP6aClient::compute_key
 *
 */
int clsSRP6aClient::compute_key(unsigned char** p_pucResult,
								const unsigned char* p_pucServerPublicKey, int p_iServerPublicKeyLength) {
	
	int	result = SRP_ERROR;
	
	// srp6a_client_key
	int	modulusLength = (int)(mpz_sizeinbase(m_bnModulus, 2) + 7) / 8;	// in byte
	if (p_iServerPublicKeyLength <= modulusLength) {
		SHA512	sha512;
		sha512.clear();
		
		unsigned char*	pucS = new unsigned char[modulusLength];
		size_t			count;
		mpz_export((void*)pucS, &count, 1, 1, 1, 0, m_bnModulus);
		sha512.update(pucS, count);
		
		// prepare generator (left padded with 0)
		mpz_export((void*)pucS, &count, 1, 1, 1, 0, m_bnGenerator);
		memmove(pucS + (modulusLength - count), pucS, count);
		memset(pucS, 0, (modulusLength - count));
		sha512.update(pucS, modulusLength);
		
		unsigned char	dig[SHA512_DIGESTSIZE];
		sha512.finalize(dig, sizeof(dig));
		
		mpz_t	bnK;
		mpz_init(bnK);
		mpz_import(bnK, SHA512_DIGESTSIZE, 1, 1, 1, 0, dig);
		
		if (0 != mpz_cmp_ui(bnK, 0)) {
			// srp6_client_key_ex
			sha512.clear();
			
			// H(A)
			mpz_export((void*)pucS, &count, 1, 1, 1, 0, m_bnPublicKey);
			memmove(pucS + (modulusLength - count), pucS, count);
			memset(pucS, 0, (modulusLength - count));
			sha512.update(pucS, modulusLength);
			
			// H(A | B)
			memcpy(pucS + (modulusLength - p_iServerPublicKeyLength), p_pucServerPublicKey, p_iServerPublicKeyLength);
			memset(pucS, 0, (modulusLength - p_iServerPublicKeyLength));
			sha512.update(pucS, modulusLength);
			
			// set u
			unsigned char	dig[SHA512_DIGESTSIZE];
			sha512.finalize(dig, sizeof(dig));
			mpz_import(m_bnU, SHA512_DIGESTSIZE, 1, 1, 1, 0, dig);
			
			//hash: (H(N) xor H(g)) | H(U) | s | A | B
			m_shaHash.update(p_pucServerPublicKey, p_iServerPublicKeyLength);
			
			mpz_t	bnGB;
			mpz_init(bnGB);
			mpz_import(bnGB, p_iServerPublicKeyLength, 1, 1, 1, 0, p_pucServerPublicKey);
			if ((0 > mpz_cmp(bnGB, m_bnModulus)) &&
				(0 != mpz_cmp_ui(bnGB, 0))) {
				
				mpz_t	bnE;
				mpz_init(bnE);
				// unblind g^b (mod N)
				mpz_sub(m_bnKey, m_bnModulus, m_bnVerifier);
				// use e as temporary, e == -k*v (mod N)
				mpz_mul(bnE, bnK, /*m_bnVerifier*/m_bnKey);
				mpz_add(bnE, bnE, bnGB);
				mpz_mod(bnGB, bnE, m_bnModulus);
				
				// compute gb^(a + ux) (mod N)
				mpz_mul(bnE, m_bnPassword, m_bnU);
				mpz_add(bnE, bnE, m_bnSecretKey);
				
				mpz_powm(m_bnKey, bnGB, bnE, m_bnModulus);
				
				// convert srp->key into a session key H(key), update hash states
				mpz_export((void*)pucS, &count, 1, 1, 1, 0, m_bnKey);
				
				sha512.clear();
				sha512.update(pucS, count);
				sha512.finalize(m_aucK, sizeof(m_aucK));
				mpz_import(m_bnKey, sizeof(m_aucK), 1, 1, 1, 0, m_aucK);
				
				// hash: (H(N) xor H(g)) | H(U) | s | A | B | K
				m_shaHash.update(m_aucK, sizeof(m_aucK));
				/*unsigned char	tst[SHA512_DIGESTSIZE];
				m_shaHash.finalize(tst, sizeof(tst));
				print("shaHash:", tst, sizeof(tst));*/
				
				if (p_pucResult) {
					*p_pucResult = new unsigned char[SHA512_DIGESTSIZE];
					memcpy(*p_pucResult, m_aucK, SHA512_DIGESTSIZE);
					//print("Shared Secret K:", *p_pucResult, SHA512_DIGESTSIZE);
				}
				result = SRP_SUCCESS;
			}
		}
	}
	return result;
}

/*
 * SRP6aClient::verify
 *
 */
int clsSRP6aClient::verify(const unsigned char* p_pucServerProof, int p_iServerProofLength) {

	int				result = SRP_ERROR;
	
	if (m_bResonseSuccessfullyCreated) {
		unsigned char	expectedDig[SHA512_DIGESTSIZE];
		m_shaCKHash.finalize(expectedDig, sizeof(expectedDig));
		
		if ((SHA512_DIGESTSIZE == p_iServerProofLength) &&
			(0 == memcmp(p_pucServerProof, expectedDig, SHA512_DIGESTSIZE))) {
			
			result = SRP_SUCCESS;
		}
	}
	return result;
}

/*
 * SRP6aClient::respond
 *
 */
int clsSRP6aClient::respond(unsigned char** p_pucResponse) {

	if (0 != p_pucResponse) {
		*p_pucResponse = new unsigned char[SHA512_DIGESTSIZE];
		
		// proof contains client's response
		m_shaHash.finalize(*p_pucResponse, SHA512_DIGESTSIZE);
		//memcpy(*p_pucResponse, m_aucR, SHA512_DIGESTSIZE);
		
		// ckhash: A | M | K
		m_shaCKHash.update(*p_pucResponse, SHA512_DIGESTSIZE);
		m_shaCKHash.update(m_aucK, sizeof(m_aucK));
		
		/*unsigned char	tst[SHA512_DIGESTSIZE];
		m_shaHash.finalize(tst, sizeof(tst));
		print("shaHash:", tst, sizeof(tst));
		m_shaCKHash.finalize(tst, sizeof(tst));
		print("shaCKHash:", tst, sizeof(tst));*/
		
		m_bResonseSuccessfullyCreated = true;

		return SRP_SUCCESS;
	}
	return SRP_ERROR;
}


// HELPERS

/*
 * print(BN)
 *
 */
void clsSRP6aClient::print(const char* p_pcComment,
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
void clsSRP6aClient::print(const char* p_pcComment,
		const unsigned char* p_pucArray, int p_iLength) {

	printf("%s\n", p_pcComment);
	for (int j = 1; j <= p_iLength; ++j) {
		//Serial.write (array[j]);//Serial.write() transmits the ASCII numbers as human readable characters to serial monitor
		char s[20];
		sprintf(s, "0x%02x, ", p_pucArray[j - 1]);
		printf("%s", s);
		if (!(j % 16)) {
			printf("\n");
		}
	}
	printf("\n");
}

/*
 * print(char*)
 *
 */
void clsSRP6aClient::print(const char* p_pcComment,
		const char* p_pcString) {

	printf("%s\n", p_pcComment);
	for (unsigned j = 1; j <= strlen(p_pcString); ++j) {
		//Serial.write (array[j]);//Serial.write() transmits the ASCII numbers as human readable characters to serial monitor
		char s[20];
		sprintf(s, "%c", p_pcString[j - 1]);
		printf("%s", s);
		if (!(j % 64)) {
			printf("\n");
		}
	}
	printf("\n");
}




