/*
 * SRP6aServer.h
 *
 *  Created on: 13.10.2017
 *      Author: hartmut
 */

#ifndef SRP_SRP6ASERVER_H_
#define SRP_SRP6ASERVER_H_

//#include "../Crypto/SHA512.h"
#include "SHA512.h"
#include "mini-gmp.h"

#define SRP_SUCCESS	0
#define SRP_ERROR	(-1)


class clsSRP6aServer {
public:
	clsSRP6aServer(void);
	virtual ~clsSRP6aServer(void);

	int set_username(const char* p_pcUsername);
	int set_params(const unsigned char* p_pucModulus, int p_iModulusLength,
			const unsigned char* p_pucGenerator, int p_iGeneratorLength,
			const unsigned char* p_pucSalt, int p_iSaltLength);
	int set_authenticator(const unsigned char* p_pucAuthenticator, int p_iAuthenticatorLength);
	int set_auth_password(const char* p_pcPassword);
	int gen_pub(unsigned char** p_pucResult);

	int compute_key(unsigned char** p_pucResult,
			const unsigned char* p_pucPublicKey, int p_iPublicKeyLength);
	int verify(const unsigned char* p_pucProof, int p_iProofLength);
	int respond(unsigned char** p_pucResponse);

protected:
	unsigned char*	m_pucUsername;
	int				m_iUsernameLength;
	mpz_t			m_bnModulus;
	mpz_t			m_bnGenerator;
	unsigned char*	m_pucSalt;
	int				m_iSaltLength;
	mpz_t			m_bnVerifier;
	mpz_t			m_bnPassword;

	mpz_t			m_bnPublicKey;
	mpz_t			m_bnSecretKey;
	mpz_t			m_bnU;

	mpz_t			m_bnKey;

	SHA512			m_shaHash;
	SHA512			m_shaCKHash;
	SHA512			m_shaOldHash;
	SHA512			m_shaOldCKHash;
	unsigned char	m_aucK[SHA512_DIGESTSIZE];
	unsigned char	m_aucR[SHA512_DIGESTSIZE];
	bool			m_bRSuccessfullyCreated;
	
	void print(const char* p_pcComment,
			mpz_t p_bnValue);
	void print(const char* p_pcComment,
			const unsigned char* p_pucArray, int p_iLength);
	void print(const char* p_pcComment,
			const char* p_pString);
};


#endif /* SRP_SRP6ASERVER_H_ */



