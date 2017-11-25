/*
 * HMAC+HKDF.h
 *
 *  Created on: 29.10.2017
 *      Author: hartmut
 */

#ifndef __HMAC_HKDF_H_
#define __HMAC_HKDF_H_


#include "../Crypto/SHA512.h"

/*
 * HMAC512
 *
 */
bool HMAC512(const unsigned char* p_pucMessage, const unsigned p_uMessageLength,
		const unsigned char* p_pucKey, const unsigned p_uKeyLength,
		unsigned char* p_pucDigest, const unsigned p_uDigestLength);

/*
 * HKDF512
 *
 */
bool HKDF512(const unsigned char* p_pucSalt, const unsigned p_uSaltLength,
		const unsigned char* p_pucIKM, const unsigned p_uIKMLength,
		const unsigned char* p_pucInfo, const unsigned p_uInfoLength,
		unsigned char* p_pucOKM, const unsigned p_uOKMLength);


#endif /* __HMAC_HKDF_H_ */
