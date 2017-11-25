/*
 * HMAC+HKDF.cpp
 *
 *  Created on: 29.10.2017
 *      Author: hartmut
 */

#include <string.h>

#include "HMAC+HKDF.h"


/*
 * HMAC512
 *
 */
bool HMAC512(const unsigned char* p_pucMessage, const unsigned p_uMessageLength,
		const unsigned char* p_pucKey, const unsigned p_uKeyLength,
		unsigned char* p_pucDigest, const unsigned p_uDigestLength) {

	bool	result = false;

	if ((p_pucDigest) &&
		(SHA512_DIGESTSIZE == p_uDigestLength)) {
		SHA512	sha512;
		sha512.resetHMAC(p_pucKey, p_uKeyLength);
		sha512.update(p_pucMessage, p_uMessageLength);
		sha512.finalizeHMAC(p_pucKey, p_uKeyLength, p_pucDigest, p_uDigestLength);
		result = true;
	}
	return result;
}


/*
 * HKDF512
 *
 */
bool HKDF512(const unsigned char* p_pucSalt, const unsigned p_uSaltLength,
		const unsigned char* p_pucIKM, const unsigned p_uIKMLength,
		const unsigned char* p_pucInfo, const unsigned p_uInfoLength,
		unsigned char* p_pucOKM, const unsigned p_uOKMLength) {

	bool	result = false;

	// HKDFExtract
	unsigned		uInternalSaltLength = p_uSaltLength;
	unsigned char	aucNullSalt[SHA512_DIGESTSIZE];
	if (0 == p_pucSalt) {
		p_pucSalt = aucNullSalt;
		uInternalSaltLength = SHA512_DIGESTSIZE;
		memset(aucNullSalt, 0, uInternalSaltLength);
	}

	unsigned char	aucPRK[SHA512_DIGESTSIZE];
	if (HMAC512(p_pucIKM, p_uIKMLength, p_pucSalt, uInternalSaltLength, aucPRK, SHA512_DIGESTSIZE)) {
		// HKDFExpand

		unsigned	uInternalInfoLength = p_uInfoLength;
		if (0 == p_pucInfo) {
			p_pucInfo = (const unsigned char*)"";
			uInternalInfoLength = 0;
		}

		//unsigned	uHashLength = SHA512_DIGESTSIZE;
		unsigned	uN = p_uOKMLength / SHA512_DIGESTSIZE;
		if (0 != (p_uOKMLength % SHA512_DIGESTSIZE)) {
			++uN;
		}
		if (255 >= uN) {
			unsigned char	aucT[SHA512_DIGESTSIZE];
			unsigned		uTLength = 0;
			unsigned		uWhere = 0;
			for (unsigned u = 1; u <= uN; ++u) {
				unsigned char	c = (unsigned char)u;

				SHA512			sha512;
				sha512.resetHMAC(aucPRK, SHA512_DIGESTSIZE);
				sha512.update(aucT, uTLength);
				sha512.update(p_pucInfo, uInternalInfoLength);
				sha512.update(&c, 1);
				sha512.finalizeHMAC(aucPRK, SHA512_DIGESTSIZE, aucT, SHA512_DIGESTSIZE);

				memcpy((p_pucOKM + uWhere), aucT, ((u != uN) ? SHA512_DIGESTSIZE : (p_uOKMLength - uWhere)));
				uWhere += SHA512_DIGESTSIZE;
				uTLength = SHA512_DIGESTSIZE;
			}
			result = true;
		}
	}
	return result;
}





